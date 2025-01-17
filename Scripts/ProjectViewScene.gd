extends Control

func back() -> void:
	get_tree().change_scene_to_file("res://Scenes/Home.tscn")

func compile() -> void:
	NdsGd.buildROM(ProjManager.ProjPath.path_join("unpacked"), ProjManager.ProjPath.path_join("Compiled.nds"))

func decompressArm9() -> void:
	ProjManager.decompArm9()

func recompressArm9() -> void:
	ProjManager.recompArm9()

func _on_tree_narc_selected(narcPath: String) -> void:
	$Tree.visible = false
	ProjManager.loadNarc(narcPath)
	$NarcList.activate(ProjManager.NarcPath)

func showTree() -> void:
	$Tree.visible = true
