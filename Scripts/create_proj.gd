extends VBoxContainer


var path = "/Users/colinorourke/Desktop/GodotProjects"

var rom = "/Users/colinorourke/Desktop/GodotProjects/Roms/Heartgold.nds"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PathLabel.text = path
	$RomLabel.text = rom
	pass # Replace with function body.

func onDirSelected(selected):
	path = selected
	$PathLabel.text = path
	pass

func onRomSelected(selected: String) -> void:
	if (selected.get_extension() == "nds"):
		rom = selected
		$RomLabel.text = rom
	else:
		rom = "Invalid File!"
		$RomLabel.text = rom
	pass # Replace with function body.

func openDialog() -> void:
	$DirDialog.visible = true
	pass # Replace with function body.
	
func openRomDialog() -> void:
	$RomDialog.visible =  true
	pass # Replace with function body.

func createProject() -> void:
	if ($NameEdit.text != "" && $NameEdit.text.is_valid_filename()):
		var dir = DirAccess.open(path)
		var projectPath = path.path_join($NameEdit.text)
		dir.make_dir(projectPath)
		dir.make_dir(projectPath.path_join("/unpacked"))
		NdsGd.extractROM(rom, projectPath.path_join("/unpacked"))
		var file = FileAccess.open(projectPath + "/Project.TXT", 7)
		file.close()
	else:
		pass
	pass # Replace with function body.

func compileProject() -> void:
	var projectPath = "/Users/colinorourke/Desktop/GodotProjects".path_join($NameEdit.text)
	NdsGd.buildROM(projectPath.path_join("/unpacked"), projectPath.path_join("Compiled.nds"))
	

	
	
