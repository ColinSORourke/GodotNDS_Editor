extends Panel

signal exportSubFile(name, contents)

var myNarc: NitroArchive

var buttonDict: Dictionary
var currentButtonID: int
var buttonTexture: ImageTexture = ImageTexture.create_from_image(Image.load_from_file("res://Assets/icon.svg"))

var myFileName: String
var myFile: PackedByteArray

func activate(path: String) -> void:
	if (!FileAccess.file_exists(path)):
		# FILE DOES NOT EXIST
		$Label.text = "Bad File Path"
		return
	
	$Label.text = path.get_file()
	$ItemList.clear()
	buttonTexture.set_size_override(Vector2(32, 32))
	
	self.visible = true
	var narcBytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	myNarc = NitroArchive.new()
	var resultCode = myNarc.unpack(narcBytes)
	
	if (resultCode == -1):
		# NARC missing something
		$Label.text = "Bad NARC"
		return
	
	var i = 0
	while (i < myNarc.fatbNFiles):
		var current = $ItemList.add_item(myNarc.myFntb.names[i])
		buttonDict[currentButtonID] = myNarc.myFntb.names[i]
		currentButtonID += 1
		i += 1
	
func subfileSelected(index: int) -> void:
	myFile = myNarc.files[index]
	myFileName = myNarc.myFntb.names[index]
	$Label2.visible = true
	$Label2.text = myFileName
	var myFileString = myFile.hex_encode().to_upper()
	var i = 2
	var count = 1
	while (i < myFileString.length()):
		if (count % 8 == 0):
			myFileString = myFileString.insert(i, "\n")
		else:
			myFileString = myFileString.insert(i, " ")
		count += 1
		i += 3
	print(myFileString)
	$Label2/Panel/TextEdit.text = myFileString

func exportFile() -> void:
	exportSubFile.emit(myFileName, myFile)

class NitroArchive:
	# Hex Codes -> File Extensions
	const extensionDict: Dictionary = {
		0x424D4430 : ".bmd0",
		0x30444D42 : ".bmd0",
		
		0x42545830 : ".btx0",
		0x30585442 : ".btx0",
		
		0x4E534352 : ".ncsr",
		0x5243534E : ".ncsr",
		
		0x4E434C52 : ".nclr",
		0x524C434E : ".nclr",
		
		0x4E434752 : ".ncgr",
		0x5247434E : ".ncgr",
		
		0x4E414E52 : ".nanr",
		0x524E414E : ".nanr",
		
		0x4E4D4152 : ".nmar",
		0x52414D4E : ".nmar",
		
		0x4E4D4352 : ".nmcr",
		0x52434D4E : ".nmcr",
		
		0x4E434552 : ".ncer",
		0x5245434E : ".ncer",
	}
	
	# Hex Codes -> Magic Values I'm looking for
	const magicDict: Dictionary = {
		0x4E415243 : "NARC",
		0x4352414E : "NARC",
		
		0x42544146 : "FATB",
		0x46415442 : "FATB",
		
		0x42544E46 : "FNTB",
		0x464E5442 : "FNTB",
		
		0x474D4946 : "FIMG",
		0x46494D47 : "FIMG"
	}
	
	# NARC Header
	var myHeader: narcHeader = narcHeader.new()
	
	# File Allocation Table Block
	var fatbMagic: int
	var fatbSectionSize: int
	var fatbNFiles: int
	var fatbOffsets: Array[Vector2i] = [] # Format: Index is file number, Vector.x is StartOffset, Vector.y is EndOffset
	
	# File Name Table Block
	var myFntb: fntBlock = fntBlock.new()
	
	# File Images
	var fimgMagic: int
	var fimgSectionSize: int
	
	# All the Files
	var files: Array[PackedByteArray] = []
	
	# Narc Header Struct
	class narcHeader:
		var magic: int
		var constant: int
		var fileSize: int
		var headerSize: int
		var nSections: int
		const bufferLength: int = 16
		
		func process(bytes: PackedByteArray) -> void:
			magic = bytes.decode_u32(0)
			constant = bytes.decode_u32(4)
			fileSize = bytes.decode_u32(8)
			headerSize = bytes.decode_u16(12)
			nSections = bytes.decode_u16(14)
	
	# File Name Table Struct
	class fntBlock:
		var magic: int
		var sectionSize: int
		var offsets: Array[Vector2i] = []
		var dirStartOffset: int
		var firstFilePos: int
		var nDir: int
		var names: PackedStringArray = []
		const bufferLength: int = 8
		
		func process(bytes: PackedByteArray):
			magic = bytes.decode_u32(0)
			sectionSize = bytes.decode_u32(4)
			
		func fillNames(bytes: PackedByteArray, numFiles: int):
			dirStartOffset = bytes.decode_u32(0)
			firstFilePos = bytes.decode_u16(4)
			nDir = bytes.decode_u16(6)
			if (nDir != 1):
				# more complicated stuff
				pass
			else:
				var i = 0
				while (i < numFiles):
					names.append(str(i))
					i += 1
	
	# Unpack the NARC
	func unpack(narcBytes: PackedByteArray, decompress: bool = true) -> int:
		
		# Unpack Header
		myHeader.process(narcBytes.slice(0, narcHeader.bufferLength))
		
		if (myHeader.magic not in magicDict || magicDict[myHeader.magic] != "NARC"):
			print("Not a NARC")
			# NOT A NARC FILE
			return -1
		
		# Unpack the File Allocation Table
		fatbMagic = narcBytes.decode_u32(16)
		fatbSectionSize = narcBytes.decode_u32(20)
		fatbNFiles = narcBytes.decode_u32(24)
		
		if (fatbMagic not in magicDict || magicDict[fatbMagic] != "FATB"):
			print("Missing FATB")
			# MISSING FATB
			return -1
		
		# Unpack the Offsets from the File Allocation Table
		var currInd = 28
		var i = 0
		while(i < fatbNFiles):
			fatbOffsets.append(Vector2i(0,0))
			fatbOffsets[i][0] = narcBytes.decode_u32(currInd)
			fatbOffsets[i][1] = narcBytes.decode_u32(currInd + 4)
			currInd += 8
			i += 1
		
		# Unpack the File Name table
		myFntb.process(narcBytes.slice(currInd, currInd + fntBlock.bufferLength))
		if (myFntb.magic not in magicDict || magicDict[myFntb.magic] != "FNTB"):
			print("Missing FNTB")
			# MISSING FNTB
			return -1
		currInd += fntBlock.bufferLength
		myFntb.fillNames(narcBytes.slice(currInd, currInd + myFntb.sectionSize), fatbNFiles)
		currInd = currInd + myFntb.sectionSize - 8
		
		# Unpack the File Image Table
		fimgMagic = narcBytes.decode_u32(currInd)
		if (fimgMagic not in magicDict ||magicDict[fimgMagic] != "FIMG"):
			print("Missing FIMG")
			# MISSING FIMG
			return -1
		fimgSectionSize = narcBytes.decode_u32(currInd + 4)
		var fimgOffset = currInd + 8
		currInd += 8
		
		# Unpack all the files into the File Array
		i = 0
		while(i < fatbNFiles):
			var extension: String = ""
			currInd = fimgOffset + fatbOffsets[i][0]
			
			# Get the files Extension
			var byte = narcBytes.decode_u8(currInd)
			if (byte != 0x11):
				byte = narcBytes.decode_u32(currInd)
				if (byte not in extensionDict):
					extension = ""
				else:
					extension = extensionDict[byte]
			else:
				extension = ".lzss"
			myFntb.names[i] = myFntb.names[i] + extension
			
			# Write the File to our array
			var fileSize = fatbOffsets[i][1] - fatbOffsets[i][0]
			files.append(narcBytes.slice(currInd, currInd + fileSize))
			currInd += fileSize
			i += 1

		return 0
