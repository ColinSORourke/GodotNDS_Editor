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
	$HexDisplay.text = myFileStringSpaced
	if (ProjManager.myFilePath == "NARC"):
		$FileButtons/Duplicate.visible = true
		$FileButtons/Export.visible = true
	else:
		$FileButtons/Duplicate.visible = false
		$FileButtons/Export.visible = false
	
func exportFile() -> void:
	ProjManager.exportFile()
	
func openFileImport() -> void:
	$FileDialog.visible = true

func close() -> void:
	self.visible = false

func importFile(path: String) -> void:
	ProjManager.importFile(path)
	self.activate()
	
func duplicateFile() -> void:
	ProjManager.duplicateFile()
	$FileName.text = ProjManager.myFileName
	addToNarcList.emit()
