// The agent's words. A small Markdown subset: paragraphs, "- " lists, **bold**, `code` and [text](link). Built as DOM nodes, never as HTML.
import { registerBlock } from "../registry.js";
import { h } from "../dom.js";

const INLINE = /(\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)\s]+\))/;

export function inline(text) {
  return text.split(INLINE).filter(Boolean).map((part) => {
    if (part.startsWith("**") && part.endsWith("**") && part.length > 4) return h("strong", {}, part.slice(2, -2));
    if (part.startsWith("`") && part.endsWith("`") && part.length > 2) return h("code", {}, part.slice(1, -1));
    const link = part.match(/^\[([^\]]+)\]\(([^)\s]+)\)$/);
    if (link && /^(https?:\/\/|#|\/|[\w./-]+$)/.test(link[2])) return h("a", { href: link[2], target: link[2].startsWith("http") ? "_blank" : null, rel: "noopener" }, link[1]);
    return part;
  });
}

export function markdown(text) {
  const out = [];
  for (const chunk of String(text).split(/\n\s*\n/)) {
    const lines = chunk.split("\n").filter((l) => l.trim());
    if (!lines.length) continue;
    if (lines.every((l) => /^\s*[-*] /.test(l))) out.push(h("ul", {}, lines.map((l) => h("li", {}, inline(l.replace(/^\s*[-*] /, ""))))));
    else out.push(h("p", {}, inline(lines.join(" "))));
  }
  return out;
}

registerBlock("note", (el, data) => {
  el.classList.add("note");
  el.append(...markdown(data.markdown || ""));
});
