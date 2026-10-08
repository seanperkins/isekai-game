// The reviewer's flags and notes: three buttons and a note box, on a creature and on each of its clips. Posts to /api/feedback; the agent reads them with
// tools/review/feedback.py. A note that does not go through stays in its box and is sent again when the connection returns.
import { h } from "../dom.js";

const FLAGS = [["ok", "right"], ["wrong", "wrong"], ["change", "change this"]];
const pending = [];   // entries that did not go through

async function post(entry) {
  const res = await fetch("/api/feedback", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(entry) });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(body.error || `HTTP ${res.status}`), { rejected: true });
  return body;
}

export async function retryPending() {
  for (const entry of pending.splice(0)) {
    try {
      await post(entry);
    } catch (err) {
      if (!err.rejected) pending.push(entry);   // still unreachable; a refused entry is dropped, it would be refused again
    }
  }
}

export function flagBar(creature, clip = null, { compact = false } = {}) {
  const note = h("input", { type: "text", maxlength: "2000", placeholder: clip ? `note on ${clip}` : "note on this creature", "aria-label": "note" });
  const status = h("span", { class: "fb-status" });
  const send = async (flag) => {
    const entry = { creature, flag, note: note.value.trim() };
    if (clip) entry.clip = clip;
    try {
      const saved = await post(entry);
      note.value = "";
      status.textContent = `saved #${saved.id}`;
    } catch (err) {
      if (!err.rejected) pending.push(entry);
      status.textContent = err.rejected ? `not saved: ${err.message}` : "not saved: the server did not answer; will retry";
    }
  };
  return h("div", { class: "flagbar" + (compact ? " compact" : "") },
    FLAGS.map(([flag, label]) => h("button", { type: "button", class: "flag flag-btn-" + flag, onclick: () => send(flag) }, label)), note, status);
}
