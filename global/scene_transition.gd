extends CanvasLayer
## Global fade-to-black scene transitions. Autoloaded as `Transition`.
##
## Owns a full-screen black overlay on a top-most CanvasLayer that persists across
## scene swaps (autoloads aren't part of the scene being swapped). change_scene_to()
## fades to black, swaps the scene while the screen is covered, then fades back in
## -- so a level fades in on load and fades out on leave. transition() is the
## generic version: it runs any action while the screen is black.

const FADE_DURATION := 0.3
## Layer high enough to sit above every scene's own CanvasLayers.
const OVERLAY_LAYER := 128

## Seconds each fade takes. A plain var so tests can shorten it.
var fade_duration := FADE_DURATION

var _overlay: ColorRect
var _busy := false


func _ready() -> void:
	layer = OVERLAY_LAYER
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)  # black, fully transparent to start
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # invisible == click-through
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


## Fades to black, swaps to the scene at `path`, then fades back in.
func change_scene_to(path: String) -> void:
	await transition(func(): get_tree().change_scene_to_file(path))


## Fades to black, runs `action` while the screen is covered, then fades back in.
## Ignored if a transition is already running.
func transition(action: Callable) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow input mid-transition
	await fade_out()
	action.call()
	await get_tree().process_frame  # let the swapped-in scene enter the tree
	await fade_in()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Fades the screen to opaque black.
func fade_out() -> void:
	await _fade_to(1.0)


## Fades the screen back to fully transparent.
func fade_in() -> void:
	await _fade_to(0.0)


func _fade_to(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", target_alpha, fade_duration)
	await tween.finished
