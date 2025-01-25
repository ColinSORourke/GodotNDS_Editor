extends Node

var ProjName: String = "Placeholder"
var ProjPath: String = "Placeholder"

var ProjHeader: NdsGd.NitroHeader = null
var HeaderPath: String = "Placeholder"

var ProjRoot: NdsGd.NitroDirectory = null
var RootPath: String = "Placeholder"

var myNarc: NdsGd.NitroArchive = null
var NarcPath: String = "Placeholder"

var myPalette: FileFormats.Palette = null
var myPalettePath: String = "Placeholder"

var myFile: PackedByteArray = []
var myFileName: String
var myFilePath: String
var myFileIndex: int
var myImage: FileFormats.IndexedImage = null

var arm9Comp: bool = true
# Quick test suggested ROM still runs whether or not each overlay is compressed.
	# Test was: Decompress Overlay_0001.bin on Heartgold, re-compile rom with Decompressed 0001, Rom launched
# If this is NOT THE CASE
	# I should not overwrite each Overlay when it gets decompressed.
var overlayComps: Array[String] = []
# ALSO: If I provide Overlay Re-compression, I need to be able to identify if the overlay 'can't be compressed'
# If I try to Decompress an Uncompressed File, Decompress just quits and does not create a new file.

func _ready() -> void:
	myPalette = FileFormats.Palette.new()
	myPalette.initNum(16)

func iscompArm9() -> void:
	# ERROR NOTE: I am not 100% sure this check is accurate all of the time?
		# I am basing it on a comment from NDSPY that _DetectAppendData returns none if the file doesn't seem to be compressed.
	arm9Comp = Compression.checkCompressed(ProjPath.path_join("unpacked/arm9.bin"))

func overlaysCompressed() -> void:
	var overlayDir: DirAccess = DirAccess.open(ProjPath.path_join("unpacked/overlays"))
	var overlays: Array = overlayDir.get_files()
	var i = 0
	while (i < overlays.size()):
		if ( !Compression.checkCompressed(ProjPath.path_join("unpacked/overlays").path_join(overlays[i])) ):
			overlayComps.append(overlays[i])
		i += 1

func decompArm9() -> void:
	Compression.Decompress(ProjPath.path_join("unpacked/arm9.bin"), true)
	arm9Comp = false
	
func recompArm9() -> void:
	Compression.Compress(ProjPath.path_join("unpacked/arm9.bin"), true, true)
	arm9Comp = true

func loadFile(path: String) -> void:
	var filePath = ProjPath.path_join("unpacked").path_join(path)
	var fileBytes: PackedByteArray = FileAccess.get_file_as_bytes(filePath)
	if (NdsGd.NitroArchive.isNarc((fileBytes))):
		NarcPath = filePath
		myNarc = NdsGd.NitroArchive.new()
		var resultCode: int = myNarc.unpack(fileBytes)
	else:
		myFile = fileBytes
		myFileName = path.get_file()
		myFilePath = filePath
		myFileIndex = -1
		NarcPath = "Not a NARC"
	fileSwapped()
	
func loadNarcFile(index: int) -> void:
	myFile = myNarc.files[index]
	myFileName = myNarc.myFntb.names[index]
	myFilePath = "NARC"
	myFileIndex = index
	fileSwapped()

func exportFile() -> void:
	print("Generic File Export")
	exportGeneric(myFileName, myFile)
	
func importFile(path: String) -> void:
	writeGeneric(FileAccess.get_file_as_bytes(path))
	fileSwapped()

func exportJascPal() -> void:
	var expPalette = FileFormats.Palette.new()
	expPalette.initFromBytes(myFile)
	var jascStrings = expPalette.toJascPal()
	
	var exportPath = initExport(myFileName, ".pal")
	var expFile: FileAccess = FileAccess.open(exportPath, FileAccess.WRITE)
	var i = 0
	while (i < jascStrings.size()):
		expFile.store_line(jascStrings[i])
		i += 1
	expFile.close()

func importJascPal(path: String) -> void:
	var newPalette: FileFormats.Palette = FileFormats.Palette.new()
	var jascText: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	newPalette.initFromJasc(jascText)
	myPalette = newPalette
	writeGeneric(myPalette.toBytes())
	fileSwapped()

func importPngPal(path: String) -> void:
	var idxImage: FileFormats.IndexedImage = FileFormats.IndexedImage.new()
	idxImage.fromPNG(FileAccess.get_file_as_bytes(path))
	myPalette = idxImage.myPalette
	writeGeneric(myPalette.toBytes())
	fileSwapped()

func importPngImg(path: String) -> ImageTexture:
	var ncgrParams = myImage.myParams
	myImage = FileFormats.IndexedImage.new()
	myImage.fromPNG(FileAccess.get_file_as_bytes(path))
	print("Starting NCGR Bytes")
	writeGeneric(myImage.toNCGR(ncgrParams))
	myImage.updatePalette(myPalette)
	return ImageTexture.create_from_image(myImage.myImage)

func duplicateFile() -> void:
	if (myFilePath == "NARC"):
		myNarc.duplicate(myFileIndex)
		myFileIndex = myNarc.files.size() - 1
		myNarc.pack(NarcPath, true)
		myFileName = myNarc.myFntb.names[myFileIndex]
		fileSwapped()

func loadPalette() -> ImageTexture:
	myPalette = FileFormats.Palette.new()
	myPalette.initFromBytes(myFile)
	myPalettePath = myFileName
	var myTexture: ImageTexture = ImageTexture.create_from_image(myPalette.toImage())
	return myTexture

func getPaletteTexture() -> ImageTexture:
	var myTexture: ImageTexture = ImageTexture.create_from_image(myPalette.toImage())
	return myTexture

func fileSwapped() -> void:
	myImage = null

func loadImage() -> ImageTexture:
	if (!FileFormats.NCGR.isNCGR(myFile)):
		print("Not an image!")
		return null
	myImage = FileFormats.IndexedImage.new()
	myImage.fromNCGR(myFile, myPalette)
	var myTexture: ImageTexture = ImageTexture.create_from_image(myImage.myImage)
	return myTexture

func exportImage() -> void:
	if (myImage == null):
		print("No loaded image to export!")
		return
	exportGeneric(myFileName, myImage.toPNG(), ".png")
	

func getImageTexture() -> ImageTexture:
	if (myImage != null):
		var myTexture: ImageTexture = ImageTexture.create_from_image(myImage.toImage())
		return myTexture
	return null
	
func exportGeneric(fileName: String, fileBytes: PackedByteArray, extension: String = "NONE"):
	var exportPath = initExport(fileName, extension)
	var f: FileAccess = FileAccess.open(exportPath, FileAccess.WRITE)
	f.store_buffer(fileBytes)
	f.close()
	
func initExport(fileName: String, extension: String) -> String:
	# Create Exports folder if not already exists
	if (!FileAccess.file_exists(ProjPath.path_join("exported"))):
		DirAccess.make_dir_absolute(ProjPath.path_join("exported"))
	
	if (extension == "NONE"):
		extension = "." + fileName.get_extension()
	
	# Adjust the filename to not overwrite a previous export
	var expFileName: String = fileName.get_file().get_basename()
	var exportPath: String = ProjPath.path_join("exported").path_join(expFileName) + extension
	var i: int = 0
	while(FileAccess.file_exists(exportPath)):
		var extraName: String = expFileName + "_" + str(i) + extension
		exportPath = ProjPath.path_join("exported").path_join(extraName)
		i += 1
	
	return exportPath

func writeGeneric(fileBytes: PackedByteArray):
	if (myFilePath == "NARC"):
		myNarc.files[myFileIndex] = fileBytes
		myNarc.pack(NarcPath, true)
		myFile = myNarc.files[myFileIndex]
	else:
		myFile = fileBytes
		var writer = FileAccess.open(myFilePath, FileAccess.WRITE)
		writer.store_buffer(myFile)
		writer.close()
