@tool
extends Node2D
class_name Wire
## Purely cosmetic wiring. Holds an arbitrary number of child Sprite2D segments
## that together draw a line from a detector to the thing it powers. A single
## activate()/deactivate() (or setting `activated`) swaps every segment between
## its lit and unlit texture, so a level wires up visual feedback with one call:
##   $Wire.activate()
## It is decoration only -- no block_type, not part of the grid/laser physics.
##
## Build a wire by instancing this scene into a level and adding/duplicating
## Sprite2D children (position and rotate each freely to trace the path). Any
## Sprite2D descendant is picked up automatically. @tool means toggling
## `activated` in the editor previews the lit/unlit state while you place them.

const TEXTURE_ACTIVATED := preload("res://tileset/wire/wire_activated.png")
const TEXTURE_DEACTIVATED := preload("res://tileset/wire/wire_deactivated.png")

## Whether the wire currently reads as powered. Exported so a level can set the
## default in the editor; level code flips it via activate()/deactivate().
@export var activated := false: set = set_activated


func _ready() -> void:
	_refresh()


## Light every segment.
func activate() -> void:
	set_activated(true)


## Dim every segment.
func deactivate() -> void:
	set_activated(false)


func set_activated(value: bool) -> void:
	activated = value
	if is_node_ready():
		_refresh()


## Swaps every Sprite2D descendant to the texture matching the current state.
func _refresh() -> void:
	var texture := TEXTURE_ACTIVATED if activated else TEXTURE_DEACTIVATED
	for sprite in _segments(self):
		sprite.texture = texture


## Collects every Sprite2D under `node` (recursively), so nested groupings of
## segments still all respond to a single activate() call.
func _segments(node: Node) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for child in node.get_children():
		if child is Sprite2D:
			found.append(child)
		found.append_array(_segments(child))
	return found
