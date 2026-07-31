class_name ControllerType
## Classifies a connected joypad into a broad brand family and picks the
## confirm-button label to show for it (GEN-564's "A if xbox/switch, X if
## playstation").
##
## There is no built-in Godot API for controller TYPE -- input is deliberately
## device-agnostic. Godot does normalize joypad names through its bundled SDL
## controller database, so substring-matching Input.get_joy_name() is reasonably
## robust. For full per-brand glyph sets the community "Controller Icons" addon
## (rsubtil/godot-controller-icons) is the heavier standard option; this stays
## dependency-free for the placeholder.

enum Kind { GENERIC, XBOX, PLAYSTATION, NINTENDO }

const _PLAYSTATION := ["playstation", "dualshock", "dualsense", "sony", "ps3", "ps4", "ps5"]
const _NINTENDO := ["nintendo", "switch", "joy-con", "joycon", "joy con", "pro controller"]
const _XBOX := ["xbox", "xinput", "microsoft"]


## The family of the joypad at `device` (default: the first connected pad, or
## GENERIC when none is connected).
static func kind_of(device := -1) -> Kind:
	if device < 0:
		var pads := Input.get_connected_joypads()
		if pads.is_empty():
			return Kind.GENERIC
		device = pads[0]
	return from_name(Input.get_joy_name(device))


## The family implied by a raw joypad name.
static func from_name(joy_name: String) -> Kind:
	var n := joy_name.to_lower()
	if _contains_any(n, _PLAYSTATION):
		return Kind.PLAYSTATION
	if _contains_any(n, _NINTENDO):
		return Kind.NINTENDO
	if _contains_any(n, _XBOX):
		return Kind.XBOX
	return Kind.GENERIC


## The confirm-button label to show: PlayStation's cross (rendered "X"), else "A"
## (Xbox / Nintendo / generic).
static func confirm_label(kind: Kind) -> String:
	return "X" if kind == Kind.PLAYSTATION else "A"


static func _contains_any(haystack: String, needles: Array) -> bool:
	for needle in needles:
		if haystack.contains(needle):
			return true
	return false
