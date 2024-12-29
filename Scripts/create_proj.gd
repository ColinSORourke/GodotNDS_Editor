extends VBoxContainer


var path = ""

var rom = ""

func open() -> void:
	self.visible = true
	
func close() -> void:
	self.visible = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$RomLabel.text = rom

func openRomDialog() -> void:
	$RomDialog.visible =  true

func onRomSelected(selected: String) -> void:
	if (selected.get_extension() == "nds"):
		rom = selected
		$RomLabel.text = rom
	else:
		$AcceptDialog.dialog_text = "Invalid file!"
		$AcceptDialog.visible = true
	
func openDirDialog() -> void:
	if ($NameEdit.text == "" or not $NameEdit.text.is_valid_filename()):
		$AcceptDialog.dialog_text = "Invalid folder name!"
		$AcceptDialog.visible = true
	elif (rom.get_extension() != "nds"):
		$AcceptDialog.dialog_text = "Please select a ROM first!"
		$AcceptDialog.visible = true
	else:
		$DirDialog.visible = true
	

func onDirSelected(selected):
	if (DirAccess.dir_exists_absolute(selected.path_join($NameEdit.text))):
		$AcceptDialog.dialog_text = "A folder with that name already exists!"
		$AcceptDialog.visible = true
	else:
		path = selected;
		createProject()
	

func createProject() -> void:
	var dir = DirAccess.open(path)
	var projectPath = path.path_join($NameEdit.text)
	dir.make_dir(projectPath)
	dir.make_dir(projectPath.path_join("/unpacked"))
	
	# SOMETIME IN THE FUTURE
	# This should be in a "Try Catch" loop
	NdsGd.extractROM(rom, projectPath.path_join("/unpacked"))
	
	var file = FileAccess.open(projectPath + "/Project.TXT", 7)
	file.close()
