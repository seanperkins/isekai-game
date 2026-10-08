// A table of numbers: {columns: [...], rows: [[...], ...], caption}. Numbers align right.
import { registerBlock } from "../registry.js";
import { h } from "../dom.js";

registerBlock("numbers", (el, data) => {
  const cell = (tag, v) => h(tag, { class: typeof v === "number" ? "num" : "" }, v == null ? "" : String(v));
  el.append(h("table", { class: "numbers" },
    data.caption ? h("caption", {}, data.caption) : null,
    h("thead", {}, h("tr", {}, (data.columns || []).map((c) => cell("th", c)))),
    h("tbody", {}, (data.rows || []).map((row) => h("tr", {}, row.map((v) => cell("td", v)))))));
});
