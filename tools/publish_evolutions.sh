#!/usr/bin/env bash
# Publish the evolutions page (every form of every species, its world twin, the essences, the moveset and art GIFs) to GitHub
# Pages at /evolutions/. Run it when you want the live page to catch up; nothing else publishes it.
#
#   tools/publish_evolutions.sh             rebuild the data, commit, push, wait for the Pages build, check the live page matches
#   tools/publish_evolutions.sh --dry-run   rebuild and show what would change; commits and pushes nothing
#
# It runs tools/build_evolutions.py (the GIFs are made by tools/moveset_gifs.gd and tools/art/sprite_gifs.py and are committed
# under docs/evolutions/), then copies every file of docs/evolutions/ into the evolutions/ folder of the gh-pages branch,
# using a temporary worktree at .worktrees/gh-pages that is removed on exit. Only that folder is touched: the design review at
# the root of the site and the bestiary are published by their own scripts and are left as they are. Pages is served from
# gh-pages, never from main or docs/, so only those files are ever public.
set -euo pipefail
cd "$(dirname "$0")/.."

DRY=0
case "${1:-}" in
	"") ;;
	--dry-run) DRY=1 ;;
	*) echo "usage: tools/publish_evolutions.sh [--dry-run]" >&2; exit 2 ;;
esac

SRC=docs/evolutions
DEST=evolutions
BRANCH=gh-pages
WT=.worktrees/gh-pages

command -v gh >/dev/null || { echo "gh (the GitHub CLI) is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
[ ! -e "$WT" ] || { echo "$WT already exists: remove it with 'git worktree remove $WT' first" >&2; exit 1; }
git check-ignore -q .worktrees || { echo ".worktrees/ is not ignored by git; fix that before using it" >&2; exit 1; }
git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null || { echo "origin has no $BRANCH branch yet" >&2; exit 1; }

python3 tools/build_evolutions.py
[ -f "$SRC/index.html" ] || { echo "missing $SRC/index.html" >&2; exit 1; }

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

rm -rf "${WT:?}/$DEST"
mkdir -p "$WT/$DEST"
cp -R "$SRC/." "$WT/$DEST/"
: > "$WT/.nojekyll"
git -C "$WT" add -A

if git -C "$WT" diff --cached --quiet; then
	echo "The evolutions page on Pages is already up to date."
	exit 0
fi
git -C "$WT" diff --cached --stat | tail -8
if [ "$DRY" = 1 ]; then
	echo "Dry run: nothing committed or pushed."
	exit 0
fi

git -C "$WT" -c core.hooksPath=/dev/null commit -q -m "docs: publish the evolutions page ($(date +%F))"
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

LIVE="${URL%/}/$DEST/"
if curl -fsS "$LIVE" | cmp -s - "$SRC/index.html"; then
	echo "Published $SHA: $LIVE (the live page matches $SRC/index.html)"
else
	echo "Published $SHA: $LIVE, but the live page differs from the local file (a CDN cache may be catching up)" >&2
	exit 1
fi
