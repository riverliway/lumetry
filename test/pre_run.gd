extends GutHookScript
## GUT pre-run hook: point the global SaveData at a throwaway file for the whole
## test run, so nothing the suite does can mutate the developer's real
## user://save.json. Several tests drive gameplay that legitimately saves -- e.g.
## interacting with an emitter or pad now records a per-kind interact-hint flag
## (Room.Grid._mark_first_interaction), and test_options_menu re-saves to restore
## its mutations. The autoload already loaded the real save into memory at
## startup; this only redirects where future save() writes land.


func run() -> void:
	SaveData.save_path = "user://test_run_save.json"
