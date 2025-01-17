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

func decompArm9() -> void:
	Compression.Decompress(ProjPath.path_join("unpacked/arm9.bin"))
	
func recompArm9() -> void:
	Compression.Compress(ProjPath.path_join("unpacked/arm9decomp.bin"), ProjPath.path_join("unpacked/arm9recomp.bin"), true)

func loadNarc(path: String) -> void:
	print("Opened Narc " + path)
	NarcPath = ProjPath.path_join("unpacked").path_join(path)
	var narcBytes: PackedByteArray = FileAccess.get_file_as_bytes(NarcPath)
	myNarc = NdsGd.NitroArchive.new()
	var resultCode = myNarc.unpack(narcBytes)

func loadNarcFile(index: int) -> void:
	myFile = myNarc.files[index]
	myFileName = myNarc.myFntb.names[index]
	myFilePath = "NARC"

func exportFile() -> void:
	if (!FileAccess.file_exists(ProjPath.path_join("exported"))):
		DirAccess.make_dir_absolute(ProjPath.path_join("exported"))
		
	var exportName = ProjPath.path_join("exported").path_join(myFileName)
	var i = 0
	while(FileAccess.file_exists(exportName)):
		var extraName = myFileName.get_basename() + "_" + str(i) + "." + myFileName.get_extension()
		exportName = ProjPath.path_join("exported").path_join(extraName)
		i += 1
	
	var expFile = FileAccess.open(exportName, FileAccess.WRITE)
	expFile.store_buffer(myFile)
	expFile.close()
