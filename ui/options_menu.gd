extends Control
## The options ("Calibrations") screen: master / music / SFX volume sliders, a
## colorblind-mode toggle, and a dialogue text-speed cycle.
##
## A reusable overlay, instanced into both the title menu and the in-level pause
## menu. It reads the current values from SaveData when opened and writes each
## change straight back; persistence and live application are one and the same,
## since the audio buses (Audio) and the beam/detector glyphs (ColorSymbol) both
## react to SaveData.setting_changed. It runs with PROCESS_MODE_ALWAYS (set in the
## scene) so it works while the game is paused. Back or ESC closes it and emits
## `closed`, letting the owner return the cursor to whatever opened it.

signal closed

## Text-speed cycle order and the label shown for each (keys mirror SaveData.TEXT_SPEEDS).
const TEXT_SPEED_ORDER := ["slow", "normal", "fast"]
const TEXT_SPEED_LABEL := {"slow": "Slow", "normal": "Normal", "fast": "Fast"}

@onready var _master: HSlider = $Center/Panel/Box/Master/Slider
@onready var _music: HSlider = $Center/Panel/Box/Music/Slider
@onready var _sfx: HSlider = $Center/Panel/Box/Sfx/Slider
@onready var _master_value: Label = $Center/Panel/Box/Master/Value
@onready var _music_value: Label = $Center/Panel/Box/Music/Value
@onready var _sfx_value: Label = $Center/Panel/Box/Sfx/Value
@onready var _colorblind: Button = $Center/Panel/Box/Colorblind/Toggle
@onready var _text_speed: Button = $Center/Panel/Box/TextSpeed/Toggle
@onready var _nav: Node = $Center/Panel/Box/MenuNav

## True while open() pushes saved values into the sliders, so the value_changed
## signals that fire during the sync don't echo straight back into SaveData.
var _loading := false


func _ready() -> void:
	hide()
	_bind_slider(_master, _master_value, "master_audio")
	_bind_slider(_music, _music_value, "music_audio")
	_bind_slider(_sfx, _sfx_value, "sfx_audio")
	_colorblind.pressed.connect(_toggle_colorblind)
	_text_speed.pressed.connect(_cycle_text_speed)
	$Center/Panel/Box/Back.pressed.connect(close)


## Shows the menu, syncing every control to the saved settings and putting the
## cursor on the first slider.
func open() -> void:
	_loading = true
	_set_slider(_master, _master_value, SaveData.get_setting("master_audio"))
	_set_slider(_music, _music_value, SaveData.get_setting("music_audio"))
	_set_slider(_sfx, _sfx_value, SaveData.get_setting("sfx_audio"))
	_refresh_colorblind_label()
	_refresh_text_speed_label()
	_loading = false
	show()
	_nav.focus_first()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):  # ESC backs out
		close()
		get_viewport().set_input_as_handled()


## Wires a volume slider so its value label tracks it and a user-driven change is
## persisted (and applied) through SaveData.
func _bind_slider(slider: HSlider, value_label: Label, key: String) -> void:
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = str(int(v))
		if not _loading:
			SaveData.set_setting(key, int(v)))


## Sets a slider (and its label) without persisting -- used while loading. The
## label is set directly too, in case the value already matches and no signal fires.
func _set_slider(slider: HSlider, value_label: Label, percent) -> void:
	slider.value = int(percent)
	value_label.text = str(int(percent))


func _toggle_colorblind() -> void:
	var enabled: bool = SaveData.get_setting("colorblind_mode") == "patterned"
	SaveData.set_setting("colorblind_mode", "default" if enabled else "patterned")
	_refresh_colorblind_label()


func _refresh_colorblind_label() -> void:
	_colorblind.text = "On" if SaveData.get_setting("colorblind_mode") == "patterned" else "Off"


func _cycle_text_speed() -> void:
	var i: int = TEXT_SPEED_ORDER.find(SaveData.get_setting("text_speed"))
	SaveData.set_setting("text_speed", TEXT_SPEED_ORDER[(i + 1) % TEXT_SPEED_ORDER.size()])
	_refresh_text_speed_label()


func _refresh_text_speed_label() -> void:
	_text_speed.text = TEXT_SPEED_LABEL.get(SaveData.get_setting("text_speed"), "Normal")
