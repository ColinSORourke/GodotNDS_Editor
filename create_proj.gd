extends VBoxContainer


var path = "Sample/Path/Here/Two"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PathLabel.text = path
	pass # Replace with function body.

func onDirSelected(selected):
	path = selected
	$PathLabel.text = path
	pass


func openDialog() -> void:
	$FileDialog.visible = true
	pass # Replace with function body.


func createProject() -> void:
	if ($NameEdit.text != "" && path.is_absolute_path()):
		var dir = DirAccess.open(path)
		var projectPath = path + "/" + $NameEdit.text
		dir.make_dir(projectPath)
		var file = FileAccess.open(projectPath + "/Project.TXT", 7)
	else:
		pass
	pass # Replace with function body.
