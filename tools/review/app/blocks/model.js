// The 3D model with its clips: orbit and zoom with the mouse, a clip menu, a button for the game's side camera. {type: "model", gltf: "model.glb", clip?}
// three.js comes from a CDN, so it is loaded when the first model is shown; without it the block says so and the rest of the page is unaffected.
import { registerBlock } from "../registry.js";
import { h, notice } from "../dom.js";
import { flagBar } from "./feedback.js";

const cameras = new Map();   // creature -> its last camera, kept when the model file is replaced and the block is drawn again

registerBlock("model", async (el, data, ctx) => {
  let viewerModule;
  try {
    viewerModule = await import("../viewer.js");
  } catch (err) {
    el.append(notice("3D unavailable: three.js did not load. The rest of the page still works."));
    return;
  }
  const host = h("div", { class: "viewer-host" });
  let viewer;
  try {
    viewer = await viewerModule.createViewer(host, ctx.url(data.gltf), { width: Math.min(el.clientWidth || 720, 900), onCamera: (s) => cameras.set(ctx.creature, s) });
  } catch (err) {
    el.append(notice(`could not load ${data.gltf}: ${err.message || err}`, "error"));
    return;
  }
  if (!ctx.live()) {
    viewer.dispose();
    return;
  }
  ctx.onCleanup(() => viewer.dispose());
  const names = viewer.clips();
  if (!names.length) {
    el.append(notice("this model has no clips"), host);
    return;
  }
  if (cameras.has(ctx.creature)) viewer.setCamera(cameras.get(ctx.creature));
  const select = h("select", { title: "clip" }, names.map((n) => h("option", { value: n }, n)));
  select.value = names.includes(data.clip) ? data.clip : names.includes("walk") ? "walk" : names[0];
  const length = h("span", { class: "meta" });
  const flags = h("div", {});
  const choose = () => {
    viewer.play(select.value);
    length.textContent = `${viewer.duration(select.value).toFixed(2)} s`;
    flags.replaceChildren(flagBar(ctx.creature, select.value, { compact: true }));
    viewer.seek(ctx.time());
    viewer.render();
  };
  select.addEventListener("change", choose);
  el.append(h("div", { class: "tools" }, h("label", {}, "clip ", select), length,
    h("button", { type: "button", onclick: () => viewer.gameCamera() }, "game camera"), h("button", { type: "button", onclick: () => viewer.orbitCamera() }, "orbit camera")), host, flags);
  choose();
  ctx.onFrame((time) => {
    viewer.seek(time);
    viewer.render();
  });
});
