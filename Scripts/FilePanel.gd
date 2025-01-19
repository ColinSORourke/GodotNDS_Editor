extends Panel

signal addToNarcList

enum importEnum {NONE = 0, JASC = 1, PNGPAL = 2}
var importFlag: importEnum

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
		$FileButtons/ImportPAL.visible = true
		$FileButtons/ImportPNG.visible = true
		$FileButtons/ExportPAL.visible = true
	else:
		$FileButtons/LoadPLT.visible = false
		$FileButtons/ImportPAL.visible = false
		$FileButtons/ImportPNG.visible = false
		$FileButtons/ExportPAL.visible = false
	
	if (ProjManager.myFileName.get_extension() == "ncgr"):
		$FileButtons/LoadImage.visible = true
	else:
		$FileButtons/LoadImage.visible = false
		
	var texture = ProjManager.getPaletteTexture()
	$PLTPanel/PaletteTexture.texture = texture
	
	
func exportFile() -> void:
	ProjManager.exportFile()
	
func openFileImport() -> void:
	$FileDialog.visible = true

func cancelFileImport() -> void:
	$FileDialog.clear_filters()
	pass

func close() -> void:
	self.visible = false

func importFile(path: String) -> void:
	if (importFlag == importEnum.JASC):
		importFlag = importEnum.NONE
		ProjManager.importJascPal(path)
	elif (importFlag == importEnum.PNGPAL):
		importFlag = importEnum.NONE
		ProjManager.importPngPal(path)
	else:
		ProjManager.importFile(path)
	$FileDialog.clear_filters()
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
	$PLTPanel/PaletteTexture.texture = texture
	$PLTPanel/PaletteLabel.text = ProjManager.myPalettePath

func loadImage() -> void:
	var texture = ProjManager.loadImage()
	$Hex.visible = false
	$ImageTexture.texture = texture
	$ImageTexture.visible = true

func exportPalette() -> void:
	ProjManager.exportJascPal()

func importJascPal() -> void:
	importFlag = importEnum.JASC
	$FileDialog.add_filter("*.pal")
	openFileImport()
	
func importPngPal() -> void:
	importFlag = importEnum.PNGPAL
	$FileDialog.add_filter("*.png")
	openFileImport()
	
