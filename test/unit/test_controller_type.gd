extends GutTest
## Tests for ui/controller_type.gd: classifying a joypad name into a brand family
## and picking the confirm-button label (GEN-564: A for xbox/switch, X for
## playstation).


func test_playstation_names_classify_as_playstation():
	assert_eq(ControllerType.from_name("Sony DualSense"), ControllerType.Kind.PLAYSTATION)
	assert_eq(ControllerType.from_name("PS4 Controller"), ControllerType.Kind.PLAYSTATION)
	assert_eq(ControllerType.from_name("DualShock 4 Wireless Controller"), ControllerType.Kind.PLAYSTATION)

func test_xbox_names_classify_as_xbox():
	assert_eq(ControllerType.from_name("Xbox 360 Controller"), ControllerType.Kind.XBOX)
	assert_eq(ControllerType.from_name("Xbox Series Controller"), ControllerType.Kind.XBOX)

func test_nintendo_names_classify_as_nintendo():
	assert_eq(ControllerType.from_name("Nintendo Switch Pro Controller"), ControllerType.Kind.NINTENDO)
	assert_eq(ControllerType.from_name("Joy-Con (L)"), ControllerType.Kind.NINTENDO)

func test_unknown_names_are_generic():
	assert_eq(ControllerType.from_name("Some Random Gamepad"), ControllerType.Kind.GENERIC)
	assert_eq(ControllerType.from_name(""), ControllerType.Kind.GENERIC)

func test_classification_is_case_insensitive():
	assert_eq(ControllerType.from_name("SONY dualsense"), ControllerType.Kind.PLAYSTATION)

func test_confirm_label_is_x_only_for_playstation():
	assert_eq(ControllerType.confirm_label(ControllerType.Kind.PLAYSTATION), "X")
	assert_eq(ControllerType.confirm_label(ControllerType.Kind.XBOX), "A")
	assert_eq(ControllerType.confirm_label(ControllerType.Kind.NINTENDO), "A", "switch uses A per GEN-564")
	assert_eq(ControllerType.confirm_label(ControllerType.Kind.GENERIC), "A")
