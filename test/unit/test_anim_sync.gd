extends GutTest
## Unit tests for global/anim_sync.gd -- the global animation clock that keeps
## every AnimatedSprite2D in the "synced_anim" group on the same cycle.

func _make_synced_sprite(count := 2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()  # ships with a &"default" animation
	for i in count:
		sf.add_frame(&"default", PlaceholderTexture2D.new())
	s.sprite_frames = sf
	s.animation = &"default"
	s.add_to_group(AnimSync.GROUP)
	add_child_autofree(s)
	return s


func test_sprites_created_at_different_times_stay_in_phase():
	# A exists first; the clock runs; B is created "later" (like a laser segment
	# spawned when the player pushes a mirror mid-cycle).
	var a = _make_synced_sprite()
	AnimSync._process(0.7)
	var b = _make_synced_sprite()
	# The next tick drives every group member off the one shared clock.
	AnimSync._process(0.9)
	assert_eq(a.frame, b.frame, "both sprites land on the same frame")


func test_sync_snaps_a_new_sprite_to_the_current_phase_immediately():
	var a = _make_synced_sprite()
	AnimSync._process(1.0)  # advance A onto a nonzero-phase frame
	var b = _make_synced_sprite()
	AnimSync.sync(b)  # snap without waiting for a full tick
	assert_eq(b.frame, a.frame, "freshly synced sprite matches existing one")


func test_frame_wraps_within_the_animations_frame_count():
	var s = _make_synced_sprite(2)
	AnimSync._process(10.0)
	assert_between(s.frame, 0, 1, "frame stays within the 2-frame animation")


func test_sync_ignores_non_animated_nodes():
	# sync() must be a no-op (not crash) on a node that isn't an AnimatedSprite2D.
	var plain := Node2D.new()
	add_child_autofree(plain)
	AnimSync.sync(plain)
	pass_test("sync() tolerated a non-AnimatedSprite2D node")
