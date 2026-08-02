# room-02

Room 2 of 18, the middle room in [Prof. Newton](#lumetry/characters/prof-newton.md)'s wing, on [pushable mirrors](#lumetry/mechanics/pushable-mirrors.md).

## Puzzle

This room teaches that the laser emittter is able to be turned off, and that lasers can cross over each other. The emitter in in the top-middle of the room, facing downwards. There is a mirror on a track that bounces it up to the top left. There is another mirror on the same track that has to be pushed into place. But you can't cross the laser to get there. So the player will need to turn off the laser emitter, push the mirror into place, and then turn it back on.

To softlock yourself:
- push the two mirrors on the track together so neither one can be moved (4 spots to do this)
- get on the left side of the emitter and push the top mirror back to the right, trapping yourself via lasers

## Dialogue

**Intro Sequence 1 (if the player hasn't touched the laser / it touched her yet)**

Prof. Newton (welcoming) - Ok champ, this should be a snap for you. Just be sure not to touch the laser, it bites.

Tess (confused) - What do you mean "bites?"

**Intro Sequence 2 (if the player has already touched the laser at least once)**

Prof. Newton (welcoming) - Ok champ, this should be a snap for you. Just remember to keep your hands out of the laser this time.

Tess (grimacing) - Don't worry. I remember.

**Hint 1 (plays after the player has walked 20 tiles, if the player hasn't deactivated the laser yet)**

Prof. Newton (thinking) - I'm no IT professional... but have you tried turning it off and on again?

**Singed 1 (plays the first time a player tries to walk into a laser segment globally)**

Tess (singed) - Ouch!

Prof. Newton (grimacing) - Whoopsie! Those lasers sure are hungry today, huh?

**Fried 1 (plays the first time a laser collides with a player within the room) (if the player has interacted with the laser already)**

Prof. Newton (grimacing) - I bet you'll remember extra hard from now on. Good thing I already had the first aid kit here.

Tess (fried) - I think it is _burned_ into my memory at this point.

**Fried 2 (plays the first time a laser collides with a player within the room) (if the player has never interacted before)**

Prof. Newton (grimacing) - Oof. I've gotten nibbles before, but you got chomped. I'll go get the first aid kit...

Tess (fried) - Chomped? I think I got swallowed whole.

**Softlock 1**

Tess (confused) - Wha... how do I get out of this situation?

Prof. Newton (thinking) - No worries, I'm sure you can reset the room somehow.

**Softlock 2**

Tess (confused) - Well I certainly wasn't expecting this.

Prof. Newton (satisfied) - Sounds like an "Exceeds Expectations" on my performance review then?

**Completion 1 (plays when the detector lights up) (if laser hits in this wing = 0)**

Prof. Newton (satisfied) - Easy peezy watermelon squeezy!

Tess (confused) - Yeah! Wait... don't you mean lemon?

Prof. Newton (happy) - I have a citrus allergy. But I eat a watermelon every morning for breakfast!

Tess (confused) - A whole watermelon? _Every_ morning??

Prof. Newton (happy) - Yup! I crack it in half with my thighs!

**Completion 2 (plays when the detector lights up) (if laser hits in this wing = 1)**

Tess (victory-1) - Easy peezy lemon squeezy!

Prof. Newton (thinking) - I wonder if you could make chips out of crispy lemon skin? Make sure to bring a lemon with you next time you wander into the laser beam.

Tess (facepalm) - I don't go wandering into the laser on purpose! It was just an accident!

Prof. Newton (thinking) - I know! We could tape one to you so it gets cripsed!

Tess (grimacing) - Ew.
