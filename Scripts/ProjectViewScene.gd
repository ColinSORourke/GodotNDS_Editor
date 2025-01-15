extends Control

func back() -> void:
	get_tree().change_scene_to_file("res://Scenes/Home.tscn")

func compile() -> void:
	NdsGd.buildROM(ProjManager.ProjPath.path_join("unpacked"), ProjManager.ProjPath.path_join("Compiled.nds"))

func decompressArm9() -> void:
	ProjManager.decompArm9()

func recompressArm9() -> void:
	ProjManager.recompArm9()
