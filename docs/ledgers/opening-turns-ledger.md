# Opening battle: turns, two trucks, anger, the old lady (ledger)

Built on `feat/opening-turns` after Sean played the JRPG battle opening and gave feedback in several messages. No plan file: a bounded change to existing code, designed from his answers and messages; this is the record.

## What Sean asked for (in order)

1. "after the person goes, the truck should go. Highlight that it is their turn and let them go."
2. "The first time a person dodges, let it be successful but then another truck shows up so then there is two."
3. "if the player hits the truck with his umbrella, then the truck should get angry eyebrows and a road rage attack."
4. "by the third round an old lady shows up and your other moves get grayed out/disabled and you can only select 'save grandma'", "which pushes her out of the way and then they run you over."
5. "lets also add a life bar for the truck so after you hit it you can see that it didn't go down at all."

His answers to the three questions asked first: automatic turns with a bouncing arrow; the first Dodge you pick in any round is the free one; both trucks stay for good and hit one after the other.

## Built

- Turns: an arrow with a tag ("YOUR TURN", "TRUCK'S TURN") over whoever acts, moving with the truck as it charges. The truck's turn starts by itself 2.2 s after your result line appears; Enter sends it sooner.
- First Dodge: free (`OpeningModel.free_dodge`), no damage, the round is not used up, a second truck joins and stays; the round replays with the second truck's arrival line.
- Umbrella: angers the front truck for the rest of the fight (`_angry`); an angry truck's every attack is a road rage (rev and shake, red pulse, HONK, faster charge, screen shake, flash 1.0, hero thrown further; same damage).
- Life bars: one per truck in the Enemy window, HP 9999/9999, never moves; the umbrella floats a "0" and flashes the bar.
- Old lady: the last round only; `OpeningModel.grandma_here`/`enabled(i)`; the other five rows are grayed and the highlight cannot leave her row. The shove (clip `save`) throws her onto the pavement, he stands where she stood, and the trucks stop at him there.
- Art (Codex pipeline, contact sheet for Sean): truck `idle_angry_1/2`, `charge_angry_1/2`; commuter `save_1/2`; new `grandma` set (`idle_1/2`, `safe`). `grandma` is listed in `NOT_CREATURES` in `tools/build_bestiary.py`.
- Copy (placeholder, Sean's to rewrite in `tools/build_opening.gd`, then re-run it): `dodge_success`, `second_truck`, `grandma{id,label,prompt,result}`; `OpeningDef.MAX_ROWS` = 6 (five commands plus hers).

## Rulings

- Ruling: "the truck hits the truck with his umbrella" means the player's Fight (umbrella swing) angers the truck — Sean's follow-up says "the player hits the truck with his umbrella". Cost if wrong: one clip trigger.
- Ruling: a road rage hits for the same damage, not more — the three-round HP budget (a third per round, knock-out on the last hit) is what keeps the opening deterministic. Cost if wrong: damage multiplier in `_impact`.
- Ruling: only the front truck is angered (the one the umbrella reaches); the rage lasts the whole fight. Cost if wrong: `_angry` indexing.
- Ruling: the turn highlight is a floating arrow and tag, not the message line, so the truck's prompt and the result lines keep the message window (Sean answered "bouncing arrow" with the message saying whose turn). Cost if wrong: a one-line `_set_message`.
- Ruling: the free dodge is spent by the first Dodge picked whenever it comes; it cannot come in the last round because only Save Grandma is selectable there. If it is never picked, the fight stays one truck. Cost if wrong: `OpeningModel.act`.
- Ruling: with two trucks the round's damage is shared (5 + 5) so the HP budget stays a third a round; the last hit of the last round is the knock-out. Cost if wrong: `per_hit` in `_start_truck_turn`.
- Ruling: the old lady's round has no free-dodge replay and no choice but her; her entry in the def is optional (an empty `grandma` means a plain five-command last round). Cost if wrong: one def field.
- Ruling: the angry truck's life bar and the floating zero show on every Fight, once per swing. Cost if wrong: `_umbrella_hit`.
- Ruling: no horn or rev sound: the project has no such file and cues need an authored sound. The impact keeps `opening_impact`. Cost if wrong: add a cue and an event.

## Follow-ups

- Battle music, a horn/rev sound for the road rage.
- Sean's rewrite of the placeholder copy; the second-truck prompt reads best before round 2's "Another truck is coming."
- Her menu is still dark navy after the white fade.
- Two trucks overlap (the rear one is mostly hidden behind the front one's box); tune slots if it reads badly.

## Final review (debate:run, changeset against main, seats executor, auditor, cartographer, pentester)

- Seats not configured on this machine and so not run: executor-b, simplifier, antigravity, deepseek (the lens picked them; the config has no such entries). The cartographer's first run failed on a model its acpx agent does not advertise and was re-run on the executor's model.
- Executor: APPROVED (a bare verdict, no findings). Pentester: APPROVED, no exploitable path.
- Final: fixed damage rounding up twice (auditor, P2): with a round count that does not divide 30 and two trucks, a round cost more than its share and HP ran out before the last round. HP now follows one schedule (after round r of n it is MAX_HP minus ceil(MAX_HP·r/n)); a round's drop is shared between the trucks — `test_hp_runs_out_exactly_on_the_last_round_with_*` RED→GREEN.
- Final: fixed a custom old-lady id silently skipping the shove (auditor, P2): the scene dispatched on the literal id "grandma"; it now asks `OpeningModel.grandma_chosen()` — `test_saving_works_whatever_the_old_lady_is_called` and `test_the_model_says_when_the_old_lady_was_chosen_whatever_her_id` RED→GREEN.
- Final: minor (deferred): `docs/superpowers/specs/2026-10-04-the-opening-design.md` (cartographer) describes the first, code-drawn opening ("every choice fails", one truck drawn with `_draw`). It was already superseded by the JRPG-battle redo before this branch; the design doc, playtest checklist and this ledger carry the current description. Mark it superseded when someone next touches it.
