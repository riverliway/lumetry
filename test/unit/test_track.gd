extends GutTest
## Unit tests for tileset/track/track.gd -- a track publishes the hex directions a
## block may be pushed along, derived in _ready() from which of its six directional
## sprite children are visible. (The push rules that consume `directions` are
## covered in test/integration/test_movement.gd.)

const TrackScene: PackedScene = preload("res://tileset/track/track.tscn")

## Track sprite child name -> the direction it enables (mirrors track.gd/_ready).
const DIR_NODES := {
	"Top": Util.DIRECTION.UP,
	"Bottom": Util.DIRECTION.DOWN,
	"BottomLeft": Util.DIRECTION.DOWN_LEFT,
	"BottomRight": Util.DIRECTION.DOWN_RIGHT,
	"TopLeft": Util.DIRECTION.UP_LEFT,
	"TopRight": Util.DIRECTION.UP_RIGHT,
}


## Instantiates a track with exactly the named children visible, then adds it to
## the tree so _ready() builds `directions` from that visibility.
func _make_track(visible_nodes: Array):
	var track = TrackScene.instantiate()
	for node_name in DIR_NODES:
		track.get_node(node_name).visible = node_name in visible_nodes
	add_child_autofree(track)  # _ready runs on entering the tree
	return track


func test_block_type_is_track():
	assert_eq(_make_track([]).block_type, Util.BLOCK_TYPE.TRACK)


func test_no_visible_arms_means_no_directions():
	assert_eq(_make_track([]).directions, [] as Array[Util.DIRECTION])


func test_all_visible_arms_enable_all_six_directions():
	var track = _make_track(DIR_NODES.keys())
	assert_eq(track.directions.size(), 6, "every direction enabled")
	for dir in DIR_NODES.values():
		assert_true(track.directions.has(dir), "direction %d present" % dir)


func test_only_visible_arms_are_enabled():
	var track = _make_track(["Top", "BottomRight"])
	assert_eq(track.directions.size(), 2, "exactly the two visible arms")
	assert_true(track.directions.has(Util.DIRECTION.UP), "Top -> UP")
	assert_true(track.directions.has(Util.DIRECTION.DOWN_RIGHT), "BottomRight -> DOWN_RIGHT")
	assert_false(track.directions.has(Util.DIRECTION.DOWN), "hidden Bottom arm excluded")
