extends Node

var ProjName: String = "Placeholder"
var ProjPath: String = "Placeholder"

var ProjHeader: NdsGd.NitroHeader = null
var HeaderPath: String = "Placeholder"

var ProjRoot: NdsGd.NitroDirectory = null
var RootPath: String = "Placeholder"

var NarcPath: String = "Placeholder"

func decompArm9() -> void:
	Compression.Decompress(ProjPath.path_join("unpacked/arm9.bin"))
	
func recompArm9() -> void:
	Compression.Compress(ProjPath.path_join("unpacked/arm9decomp.bin"), ProjPath.path_join("unpacked/arm9recomp.bin"), true)

func loadNarc(path: String) -> void:
	NarcPath = ProjPath.path_join("unpacked").path_join(path)
