extends GutTest
## Wiring tests for the title menu (title_menu.gd): each of the three options
## connects to a handler. Builds the Center/Menu/<Button> hierarchy the script
## expects from synthetic nodes rather than loading the real scene.

const TitleMenuScript := preload("res://title_menu.gd")


## A Control running the menu script with the Center/Menu/<name> button layout,
## added to the tree so _ready() runs and wires the buttons.
func _make_menu() -> Control:
	var root := Control.new()
	root.set_script(TitleMenuScript)
	var center := CenterContainer.new()
	center.name = "Center"
	root.add_child(center)
	var menu := VBoxContainer.new()
	menu.name = "Menu"
	center.add_child(menu)
	for button_name in ["Experiments", "Calibrations", "DropOut"]:
		var button := Button.new()
		button.name = button_name
		menu.add_child(button)
	add_child_autofree(root)
	return root


func test_each_option_is_wired():
	var menu := _make_menu()
	for button_name in ["Experiments", "Calibrations", "DropOut"]:
		var button: Button = menu.get_node("Center/Menu/%s" % button_name)
		assert_gt(button.pressed.get_connections().size(), 0, "%s is connected to a handler" % button_name)
