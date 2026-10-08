// An image, GIF or SVG from the creature's folder with a caption: a reference figure, a diagram. A missing file is named, not left as a broken icon.
import { registerBlock } from "../registry.js";
import { h, notice } from "../dom.js";

registerBlock("figure", (el, data, ctx) => {
  const img = h("img", { alt: data.caption || data.src });
  img.addEventListener("error", () => el.replaceChildren(notice(`missing: ${data.src}`)), { once: true });
  img.src = ctx.url(data.src);
  el.append(img, data.caption ? h("figcaption", { class: "meta" }, data.caption) : null);
});
