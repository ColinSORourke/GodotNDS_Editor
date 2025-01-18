extends Panel

signal addToNarcList

func activate() -> void:
	self.visible = true
	$FileName.visible = true
	$FileName.text = ProjManager.myFileName
	var myFileString = ProjManager.myFile.hex_encode().to_upper()
	var myFileStringSpaced = ""
	myFileStringSpaced = myFileStringSpaced.rpad(myFileString.length() * 1.5)
	var i = 2
	var newPos = 2
	var count = 1
	while (i < myFileString.length() + 1):
		myFileStringSpaced[newPos - 2] = myFileString[i-2]
		myFileStringSpaced[newPos - 1] = myFileString[i-1]
		if (i != myFileString.length() && count % 8 == 0):
			myFileStringSpaced[newPos] = "\n"
		count += 1
		i += 2
		newPos += 3
	$Hex/HexDisplay.text = myFileStringSpaced
	
	if (ProjManager.myFilePath == "NARC"):
		$FileButtons/Duplicate.visible = true
		$FileButtons/Export.visible = true
	else:
		$FileButtons/Duplicate.visible = false
		$FileButtons/Export.visible = false
		
	if (ProjManager.myFileName.get_extension() == "nclr"):
		$FileButtons/LoadPLT.visible = true
	else:
		$FileButtons/LoadPLT.visible = false
	var texture = ProjManager.getPaletteTexture()
	$PaletteTexture.texture = texture
	
func exportFile() -> void:
	ProjManager.exportFile()
	
func openFileImport() -> void:
	$FileDialog.visible = true

func close() -> void:
	self.visible = false

func importFile(path: String) -> void:
	ProjManager.importFile(path)
	self.activate()
	
func goto() -> void:
	var position = $Hex/LineEdit.text.hex_to_int() + ($Hex/LineEdit.text.hex_to_int() / 2)
	$Hex/HexDisplay.select(position/ 24, position % 24, position / 24, position % 24 + 4, 0)
	$Hex/HexDisplay.scroll_vertical = position/ 24

func duplicateFile() -> void:
	ProjManager.duplicateFile()
	$FileName.text = ProjManager.myFileName
	addToNarcList.emit()

func loadPalette() -> void:
	var texture = ProjManager.loadPalette()
	$PaletteTexture.texture = texture
	$PaletteTexture.visible = true
