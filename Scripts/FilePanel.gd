extends Panel

func activate() -> void:
	self.visible = true
	$FileName.visible = true
	$FileName.text = ProjManager.myFileName
	var myFileString = ProjManager.myFile.hex_encode().to_upper()
	var i = 2
	var count = 1
	while (i < myFileString.length()):
		if (count % 8 == 0):
			myFileString = myFileString.insert(i, "\n")
		else:
			myFileString = myFileString.insert(i, " ")
		count += 1
		i += 3
	$HexDisplay.text = myFileString
	
func exportFile() -> void:
	ProjManager.exportFile()

func close() -> void:
	self.visible = false
