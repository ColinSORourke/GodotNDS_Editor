extends Node

var ProjName: String = "Placeholder"
var ProjPath: String = "Placeholder"

var ProjHeader: NdsGd.NitroHeader = null
var HeaderPath: String = "Placeholder"

var ProjRoot: NdsGd.NitroDirectory = null
var RootPath: String = "Placeholder"

var myNarc: NdsGd.NitroArchive = null
var NarcPath: String = "Placeholder"

var myFile: PackedByteArray = []
var myFileName: String
var myFilePath: String
var myFileIndex: int

var arm9Comp: bool = true
# Quick test suggested ROM still runs whether or not each overlay is compressed.
	# Test was: Decompress Overlay_0001.bin on Heartgold, re-compile rom with Decompressed 0001, Rom launched
# If this is NOT THE CASE
	# I should not overwrite each Overlay when it gets decompressed.
var overlayComps: Array[String] = []
# ALSO: If I provide Overlay Re-compression, I need to be able to identify if the overlay 'can't be compressed'
# If I try to Decompress an Uncompressed File, Decompress just quits and does not create a new file.

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
	

func loadNarcFile(index: int) -> void:
	myFile = myNarc.files[index]
	myFileName = myNarc.myFntb.names[index]
	myFilePath = "NARC"
	myFileIndex = index

func exportFile() -> void:
	if (!FileAccess.file_exists(ProjPath.path_join("exported"))):
		DirAccess.make_dir_absolute(ProjPath.path_join("exported"))
		
	var exportName: String = ProjPath.path_join("exported").path_join(myFileName)
	var i: int = 0
	while(FileAccess.file_exists(exportName)):
		var extraName: String = myFileName.get_basename() + "_" + str(i) + "." + myFileName.get_extension()
		exportName = ProjPath.path_join("exported").path_join(extraName)
		i += 1
	
	var expFile: FileAccess = FileAccess.open(exportName, FileAccess.WRITE)
	expFile.store_buffer(myFile)
	expFile.close()
	
func importFile(path: String) -> void:
	if (myFilePath == "NARC"):
		myNarc.files[myFileIndex] = FileAccess.get_file_as_bytes(path)
		myNarc.pack(NarcPath, true)
		myFile = myNarc.files[myFileIndex]
	else:
		myFile = FileAccess.get_file_as_bytes(path)
		var writer = FileAccess.open(myFilePath, FileAccess.WRITE)
		writer.store_buffer(myFile)
		writer.close()

func duplicateFile() -> void:
	if (myFilePath == "NARC"):
		myNarc.duplicate(myFileIndex)
		myFileIndex = myNarc.files.size() - 1
		myNarc.pack(NarcPath, true)
		myFileName = myNarc.myFntb.names[myFileIndex]
