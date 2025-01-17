extends Control

func _ready() -> void:
	if (ProjManager.arm9Comp):
		$Decomp.visible = true
	else:
		$Recomp.visible = true
		
func back() -> void:
	get_tree().change_scene_to_file("res://Scenes/Home.tscn")

func compile() -> void:
	NdsGd.buildROM(ProjManager.ProjPath.path_join("unpacked"), ProjManager.ProjPath.path_join("Compiled.nds"))

func decompressArm9() -> void:
	ProjManager.decompArm9()
	$Decomp.visible = false
	$Recomp.visible = true

func recompressArm9() -> void:
	ProjManager.recompArm9()
	$Recomp.visible = false
	$Decomp.visible = true

func onFileSelected(filePath: String) -> void:
	ProjManager.loadFile(filePath)
	if (ProjManager.NarcPath != "Not a NARC"):
		$Tree.visible = false
		$NarcList.activate()
		$FilePanel.close()
	else:
		$FilePanel.activate()

func showTree() -> void:
	$Tree.visible = true
