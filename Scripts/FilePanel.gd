extends Tree

var root

var buttonDict: Dictionary
var currentButtonID: int
var buttonTexture: ImageTexture = ImageTexture.create_from_image(Image.load_from_file("res://Assets/icon.svg"))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	root = self.create_item()
	buttonTexture.set_size_override(Vector2(32, 32))
	populateFromNitroDir(ProjManager.ProjRoot, root)

func populateFromNitroDir(directory: NdsGd.NitroDirectory, parent: TreeItem) -> void:
	var i = 0
	var current: TreeItem
	while (i < directory.directoryList.size()):
		current= self.create_item(parent)
		current.set_text(0, directory.directoryList[i].name)
		current.set_tooltip_text(0, "Folder")
		current.set_collapsed(true)
		populateFromNitroDir(directory.directoryList[i], current)
		i += 1
		
	i = 0
	while (i < directory.fileList.size()):
		current = self.create_item(parent)
		current.set_text(0, directory.fileList[i].name)
		current.set_tooltip_text(0, "File")
		current.add_button(0, buttonTexture, currentButtonID)
		buttonDict[currentButtonID] = directory.fileList[i].path
		currentButtonID += 1
		i += 1

func _on_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	ProjManager.loadNarc(buttonDict[id])
	
	$"../Panel".activate(buttonDict[id])
