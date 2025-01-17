extends Label

signal narc_file_selected

var buttonDict: Dictionary
var currentButtonID: int
var buttonTexture: ImageTexture = ImageTexture.create_from_image(Image.load_from_file("res://Assets/icon.svg"))

func activate(path: String) -> void:
	if (!FileAccess.file_exists(path)):
		# FILE DOES NOT EXIST
		$Label.text = "Bad File Path"
		return
	
	self.text = path.get_file()
	$ItemList.clear()
	buttonTexture.set_size_override(Vector2(32, 32))
	self.visible = true
	
	var i = 0
	while (i < ProjManager.myNarc.fatbNFiles):
		var current = $ItemList.add_item(ProjManager.myNarc.myFntb.names[i])
		buttonDict[currentButtonID] = ProjManager.myNarc.myFntb.names[i]
		currentButtonID += 1
		i += 1

func cancel() -> void:
	self.visible = false
	

func narcFilePicked(index: int) -> void:
	ProjManager.loadNarcFile(index)
	narc_file_selected.emit()
