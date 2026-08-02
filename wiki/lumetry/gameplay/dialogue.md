# dialogue

How the reactive dialogue system works, and the state it reads from. Each [room](#lumetry/rooms/room-01.md) opens with a professor's portrait beside a text box (see [art direction](#lumetry/art-direction.md)) and fires further lines on trigger events mid-puzzle. Most sequences have condition-gated variants, so what plays depends on the player's history, not just where they are.

This doc is the contract every room's `## Dialogue` section is written against. If a room needs a condition this doc doesn't cover, add it here first.

## What we track

State lives at four scopes. The scope decides when a value resets, which decides how often a line can fire.

### Global state (whole run)

- `singed_ever` (bool): has the player ever been [singed](#lumetry/mechanics/laser-emitters.md), i.e. tried to walk into a live beam. Gates the global-once Singed line.
- `softlocked_ever` (bool): has the player ever softlocked. Gates Softlock 1 (fires once, run-wide) versus Softlock 2.
- `fried_rooms` (set of room ids): which rooms the player has been fried in. Feeds the [Crisped](#lumetry/gameplay/achievements.md) achievement (fried in every room).
- `softlocked_rooms` (set of room ids): which rooms the player has softlocked in. Feeds the [Boxed In](#lumetry/gameplay/achievements.md) achievement. Tracked independently of which softlock *line* played.

### Per-wing state (resets when a new professor's wing begins)

- `wing_fried_count` (int): times the player has been fried in the current wing. This is the "laser hits in this wing" the Newton rooms branch on. Drives clean-run completion variants and some Fried variants. Resets to 0 at the first room of each wing.

### Per-room state

Set the first time it happens and kept for the life of the save. **These survive an auto-reset** (see Fried): a reset rewinds the puzzle, not the player's history.

- `visited` (bool): has the player entered this room before. Gates the Intro.
- `softlocked_here` (bool): has the player softlocked in this room yet. Gates Softlock 2.
- `hint_armed` / `hint_timer`: hint bookkeeping (see Hint).
- Puzzle-specific attempt flags, e.g. `tried_switch` in [room 3](#lumetry/rooms/room-03.md), where trying to flick a switch-less emitter arms an action hint. Named per room.

### Story flags (free-form)

A bag of named booleans any line can set and any later condition can read. This is how cross-room callbacks work without hard-coding one variable per gag. Examples already in use:

- `newton_lemon_bit`: set when [room 2](#lumetry/rooms/room-02.md) Completion 2 plays; read by [room 3](#lumetry/rooms/room-03.md) Fried 2. This is the mechanism behind "Completion 2 played last room."

Keep cross-room reads to wing-openers and short-range callbacks (one room to the next). Mid-room reactive lines should read only global or same-wing state, or the combinations explode.

## When each sequence plays

### Intro

Once, at the start of the room, the first time the player enters it, and then never again. Gated by `visited`. An auto-reset does not re-fire it.

### Hint

Fires if the player is stalled. Two flavors, action-triggered preferred over timed:

- **Timed:** a set delay after the Intro finishes (rooms 1 and 2 use number of tiles walked), only if the player hasn't performed the room's key action yet.
- **Action:** the moment the player attempts a specific dead-end (room 3 fires when they try to switch an emitter that has no switch). Reads a per-room attempt flag.

(This trigger predates the timing rewrite below and keeps its room-1-through-3 behavior. Flagged so it isn't mistaken for a gap.)

### Singed

The first time the player tries to walk into an active laser beam across all rooms, and then never again. Gated by `singed_ever`. The move is refused and Tess is zapped; the room is **not** reset. Because this is global-once, the first-singe line has to carry any "these lasers are dangerous" framing itself, since no later room's Singed will play.

### Fried

When the laser beam reaches the tile the player is standing on, causing an **auto room reset**. This is distinct from Singed: Singed is Tess walking into the beam, Fried is the beam coming to Tess. Fried sets `fried_rooms += this room` and `wing_fried_count += 1`, then resets the puzzle. Which Fried variant plays is chosen by condition (typically off `wing_fried_count` and story flags).

### Softlock 1

Plays the very first time a player softlocks themselves, run-wide. Gated by `softlocked_ever`. This is the line that teaches the player they can reset the room, so it fires only once in the whole game. In the room where it fires, that room's own Softlock 2 will not also play (its first-softlock slot is spent).

### Softlock 2

Plays the first time a player softlocks themselves in that room, provided Softlock 1 is not the line firing on this event. Gated by `softlocked_here`. This is the room-flavored softlock line, and it is the one completionists chasing [Boxed In](#lumetry/gameplay/achievements.md) will read in almost every room, so it should never be boilerplate.

### Completion

Plays on room solve, when the detector reads. Variants branch on history (clean wing vs. not, whether a setup flag is set). Solving is also where a Completion line can set a story flag for the next room to read.

## Conventions

- **Scope tags.** Every variant states its scope so firing frequency is unambiguous: global-once, per-room-first, per-wing, or per-solve. Reuse the tags above rather than inventing phrasings.
- **Always write a default branch.** Any sequence with conditional variants needs a catch-all `else`, or a state the conditions don't cover plays nothing. Room 3's Fried does this right (Fried 3 is the else); room 2's Completion currently only covers `wing_fried_count` 0 and 1, and needs a default.
- **One sequence at a time.** If two triggers are eligible on the same frame, priority is Fried, then Singed, then Softlock, then Completion, then Hint. Intro only fires on entry, before any of these.
- **Resets keep history.** An auto-reset (from Fried) or a manual reset rewinds hardware and Tess's position only. Every flag and counter above persists.

## Related

- [gameplay overview](#lumetry/gameplay/overview.md), the room loop these lines hang on.
- [achievements](#lumetry/gameplay/achievements.md), including Crisped and Boxed In, which read `fried_rooms` and `softlocked_rooms`.
- the 18 [rooms](#lumetry/rooms/room-01.md), whose `## Dialogue` sections implement this contract.
