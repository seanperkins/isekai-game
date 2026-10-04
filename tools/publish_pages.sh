#!/usr/bin/env bash
# Publish the design review page and the visual guides to GitHub Pages. Run it when you want the live site to catch up; nothing else publishes.
#
#   tools/publish_pages.sh                 commit, push, wait for the Pages build, check the live pages match
#   tools/publish_pages.sh --dry-run       do everything except commit, push and wait; prints what would change
#   tools/publish_pages.sh --guides-only   publish only guides/ and leave the design review page as it is live (combine with --dry-run)
#
# It copies docs/design-review/index.html and styles.css (plus an empty .nojekyll) onto the gh-pages branch, and writes the guides
# under guides/ (tools/wrap_guide.py wraps docs/research/*-report.html into standalone pages and builds an index), using a
# temporary worktree at .worktrees/gh-pages that is removed on exit. Pages is served from gh-pages, never from main or
# docs/, so only those files are ever public. The live site can lag the local files; that is on purpose.
set -euo pipefail
cd "$(dirname "$0")/.."

DRY=0
GUIDES_ONLY=0
for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY=1 ;;
		--guides-only) GUIDES_ONLY=1 ;;
		*) echo "usage: tools/publish_pages.sh [--dry-run] [--guides-only]" >&2; exit 2 ;;
	esac
done

SRC=docs/design-review
BRANCH=gh-pages
WT=.worktrees/gh-pages
FILES=(index.html styles.css)

for f in "${FILES[@]}"; do
	[ -f "$SRC/$f" ] || { echo "missing $SRC/$f" >&2; exit 1; }
done
command -v gh >/dev/null || { echo "gh (the GitHub CLI) is required" >&2; exit 1; }
[ ! -e "$WT" ] || { echo "$WT already exists: remove it with 'git worktree remove $WT' first" >&2; exit 1; }
git check-ignore -q .worktrees || { echo ".worktrees/ is not ignored by git; fix that before using it" >&2; exit 1; }
git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null || { echo "origin has no $BRANCH branch yet" >&2; exit 1; }

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
git fetch -q origin "$BRANCH"
if git show-ref -q --verify "refs/heads/$BRANCH"; then
	git worktree add -q "$WT" "$BRANCH"
	trap 'git worktree remove --force "$WT" >/dev/null 2>&1 || true' EXIT
	git -C "$WT" merge -q --ff-only "origin/$BRANCH"
else
	git worktree add -q -b "$BRANCH" "$WT" "origin/$BRANCH"
	trap 'git worktree remove --force "$WT" >/dev/null 2>&1 || true' EXIT
fi

if [ "$GUIDES_ONLY" = 0 ]; then
	for f in "${FILES[@]}"; do
		cp "$SRC/$f" "$WT/$f"
	done
fi
: > "$WT/.nojekyll"
python3 tools/wrap_guide.py "$WT/guides" >/dev/null
git -C "$WT" add -A

if git -C "$WT" diff --cached --quiet; then
	echo "Pages is already up to date."
	exit 0
fi
git -C "$WT" diff --cached --stat
if [ "$DRY" = 1 ]; then
	echo "Dry run: nothing committed or pushed."
	exit 0
fi

WHAT="the design review and guides"
[ "$GUIDES_ONLY" = 0 ] || WHAT="the guides"
git -C "$WT" -c core.hooksPath=/dev/null commit -q -m "docs: publish $WHAT ($(date +%F))"
SHA=$(git -C "$WT" rev-parse --short=7 HEAD)
git -C "$WT" push -q origin "$BRANCH"

URL=$(gh api "repos/$REPO/pages" -q .html_url)
status=""
for _ in $(seq 1 40); do
	status=$(gh api "repos/$REPO/pages/builds/latest" -q '.status + " " + .commit[0:7]')
	case "$status" in
		"built $SHA") break ;;
		errored*) echo "Pages build failed: $status" >&2; exit 1 ;;
	esac
	sleep 6
done
[ "$status" = "built $SHA" ] || { echo "Timed out waiting for the Pages build (last status: $status)" >&2; exit 1; }

stale=()
if [ "$GUIDES_ONLY" = 0 ]; then
	curl -fsS "$URL" | cmp -s - "$SRC/index.html" || stale+=("$URL")
fi
for page in "" area-design.html species-evolution.html; do
	local_file="$WT/guides/${page:-index.html}"
	curl -fsS "${URL}guides/$page" | cmp -s - "$local_file" || stale+=("${URL}guides/$page")
done
if [ "${#stale[@]}" -eq 0 ]; then
	echo "Published $SHA: $URL (the live pages match the local files; guides at ${URL}guides/)"
else
	echo "Published $SHA: $URL, but these live pages differ from the local files (a CDN cache may be catching up): ${stale[*]}" >&2
	exit 1
fi
