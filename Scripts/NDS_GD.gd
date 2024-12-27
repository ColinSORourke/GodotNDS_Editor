extends Node

# THIS FILE MODELED AFTER
# https://github.com/JackHack96/jNdstool

static var ExtractionLog: FileAccess

func extractROM(romPath: String, dirPath: String) -> void:
	var dir = DirAccess.open(dirPath)
	
	
	var romFile: FileAccess = FileAccess.open(romPath, FileAccess.READ)
	var root: NitroDirectory = NitroDirectory.new("data", 0xf000, null)
	
	var header: NitroHeader = NitroHeader.readHeader(romFile)
	var startOffsets: Dictionary
	var endOffsets: Dictionary
	
	romFile.seek(header.fatOffset)
	
	var i: int = 0
	while (i < header.fatSize / 8):
		startOffsets[i] = romFile.get_32()
		endOffsets[i] = romFile.get_32()
		i += 1
	
	romFile.seek(header.fntOffset)
	
	NitroDirectory.loadDirFNT(root, romFile, romFile.get_position(), startOffsets, endOffsets)
	print(root.currentDirId)
	
	dir.make_dir("data")
	NitroDirectory.unpackFileTree(romFile, dirPath.path_join("data"), root)
	
	
	dir.make_dir("overlays")
	i = 0
	while (i < header.arm9OverlaySize / 0x20):
		var overlayPath = dirPath.path_join("overlays").path_join("overlay_%04d.bin" % i)
		if (!FileAccess.file_exists(overlayPath)):
			var tmpWriter: FileAccess = FileAccess.open(overlayPath, 7)
			romFile.seek(startOffsets[i])
			tmpWriter.store_buffer(romFile.get_buffer(endOffsets[i] - startOffsets[i]))
			tmpWriter.close()
		i += 1
	
	var arm7OvSize: int = header.arm7OverlaySize / 0x20
	i = 0
	while (i < arm7OvSize):
		var overlayPath = dirPath.path_join("overlays").path_join("overlay_%04d.bin" % i)
		if (!FileAccess.file_exists(overlayPath)):
			var tmpWriter: FileAccess = FileAccess.open(overlayPath, 7)
			romFile.seek(startOffsets[i + arm7OvSize])
			tmpWriter.store_buffer(romFile.get_buffer(endOffsets[i + arm7OvSize] - startOffsets[i + arm7OvSize]))
			tmpWriter.close()
		i += 1
	
	if (!FileAccess.file_exists(dirPath.path_join("header.bin"))):
		romFile.seek(0)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("header.bin"), 7)
		tmpWriter.store_buffer(romFile.get_buffer(0x200))
		tmpWriter.close()
	
	if (!FileAccess.file_exists(dirPath.path_join("arm9.bin"))):
		romFile.seek(header.arm9RomOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("arm9.bin"), 7)
		tmpWriter.store_buffer(romFile.get_buffer(header.arm9Size))
		tmpWriter.close()
		
	if (!FileAccess.file_exists(dirPath.path_join("arm9ovltable.bin"))):
		romFile.seek(header.arm9OverlayOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("arm9ovltable.bin"), 7)
		tmpWriter.store_buffer(romFile.get_buffer(header.arm9OverlaySize))
		tmpWriter.close()
		
	if (!FileAccess.file_exists(dirPath.path_join("arm7.bin"))):
		romFile.seek(header.arm7RomOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("arm7.bin"), 7)
		tmpWriter.store_buffer(romFile.get_buffer(header.arm7Size))
		tmpWriter.close()
	
	
	if (!FileAccess.file_exists(dirPath.path_join("arm7ovltable.bin"))):
		romFile.seek(header.arm7OverlayOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("arm7ovltable.bin"), 7)
		tmpWriter.store_buffer(romFile.get_buffer(header.arm7OverlaySize))
		tmpWriter.close()
		
	if (!FileAccess.file_exists(dirPath.path_join("banner.bin"))):
		romFile.seek(header.iconOffset)
		var tmpWriter: FileAccess = FileAccess.open(dirPath.path_join("banner.bin"), 7)
		tmpWriter.store_buffer(romFile.get_buffer(0x840))
		tmpWriter.close()
		
	romFile.close()
	pass


func buildROM(dirPath: String, romPath: String) -> void:
	var haveAllFiles = true
	
	if (!DirAccess.dir_exists_absolute(dirPath.path_join("data"))):
		haveAllFiles = false
	if (!DirAccess.dir_exists_absolute(dirPath.path_join("overlays"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("arm9.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("arm9ovltable.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("arm7.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("arm7ovltable.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("header.bin"))):
		haveAllFiles = false
	if (!FileAccess.file_exists(dirPath.path_join("banner.bin"))):
		haveAllFiles = false
		
	if (!haveAllFiles):
		print("Something has gone horribly wrong")
	else: 
		var romFile: FileAccess = FileAccess.open(romPath, FileAccess.WRITE_READ)
		var reader: FileAccess
		var overlays: PackedStringArray = DirAccess.open(dirPath.path_join("overlays")).get_files()
		assert(overlays != null)
		overlays.sort()
		
		var rootDir: NitroDirectory = NitroDirectory.new("data", 0xf000, null)
		var fimgOffset: int = 0
		fimgOffset += 0x4000
		
		fimgOffset += getFileSize(dirPath.path_join("arm9.bin"))
		fimgOffset = addPadding(fimgOffset)

		fimgOffset += getFileSize(dirPath.path_join("arm9ovltable.bin"))
		fimgOffset = addPadding(fimgOffset)
		var i = 0
		while (i < overlays.size()):
			fimgOffset += getFileSize(dirPath.path_join("overlays").path_join(overlays[i]))
			fimgOffset = addPadding(fimgOffset)
			i += 1
		fimgOffset += getFileSize(dirPath.path_join("arm7.bin"))
		fimgOffset = addPadding(fimgOffset)
		fimgOffset += getFileSize(dirPath.path_join("arm7ovltable.bin"))
		fimgOffset = addPadding(fimgOffset)
		var fntSize = FNT.calculateFNTSize(dirPath.path_join("data"))
		fimgOffset += fntSize
		fimgOffset = addPadding(fimgOffset)
		var fatSize = FAT.calculateFATSize(dirPath.path_join("data"))
		fimgOffset += fatSize
		fimgOffset = addPadding(fimgOffset)
		
		fimgOffset += overlays.size() * 8
		fimgOffset = addPadding(fimgOffset)
		fimgOffset += 0x840
		
		
		NitroDirectory.loadDirA(dirPath.path_join("data"), rootDir, 0xf000, overlays.size(), fimgOffset)
		print(rootDir.currentDirId)
		
		reader = FileAccess.open(dirPath.path_join("header.bin"), FileAccess.READ)
		var header: NitroHeader = NitroHeader.readHeader(reader)
		var h: PackedByteArray = PackedByteArray()
		h.resize(0x4000)
		romFile.store_buffer(h)
		
		reader = FileAccess.open(dirPath.path_join("arm9.bin"), FileAccess.READ)
		header.arm9RomOffset = romFile.get_position()
		header.arm9Size = reader.get_length()
		romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("arm9.bin")))
		while (romFile.get_position() % 4 != 0):
			romFile.store_8(0xFF)
			
		reader = FileAccess.open(dirPath.path_join("arm9ovltable.bin"), FileAccess.READ)
		header.arm9OverlayOffset = romFile.get_position()
		header.arm9OverlaySize = reader.get_length()
		romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("arm9ovltable.bin")))
		while (romFile.get_position() % 4 != 0):
			romFile.store_8(0xFF)
			
		var ovlStartOffsets: Array[int]
		var ovlEndOffsets: Array[int]
		
		i = 0
		while (i < header.arm9OverlaySize / 0x20):
			reader = FileAccess.open(dirPath.path_join("overlays").path_join(overlays[i]), FileAccess.READ)
			ovlStartOffsets.append(romFile.get_position())
			ovlEndOffsets.append(romFile.get_position() + reader.get_length())
			romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("overlays").path_join(overlays[i])))
			while (romFile.get_position() % 4 != 0):
				romFile.store_8(0xFF)
			i += 1
		
		reader = FileAccess.open(dirPath.path_join("arm7.bin"), FileAccess.READ)
		header.arm7RomOffset = romFile.get_position()
		header.arm7Size = reader.get_length()
		romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("arm7.bin")))
		while (romFile.get_position() % 4 != 0):
			romFile.store_8(0xFF)
		
		reader = FileAccess.open(dirPath.path_join("arm7ovltable.bin"), FileAccess.READ)
		header.arm7OverlayOffset = romFile.get_position()
		header.arm7OverlaySize = reader.get_length()
		romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("arm7ovltable.bin")))
		while (romFile.get_position() % 4 != 0):
			romFile.store_8(0xFF)
		
		i = header.arm9OverlaySize / 0x20
		while (i < header.arm9OverlaySize / 0x20 + header.arm7OverlaySize / 0x20):
			reader = FileAccess.open(dirPath.path_join("overlays").path_join(overlays[i]), FileAccess.READ)
			ovlStartOffsets.append(romFile.get_position())
			ovlEndOffsets.append(romFile.get_position() + reader.get_length())
			romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("overlays").path_join(overlays[i])))
			while (romFile.get_position() % 4 != 0):
				romFile.store_8(0xFF)
			i += 1
			
		header.fntOffset = romFile.get_position()
		FNT.writeFNT(romFile, rootDir)
		header.fntSize = romFile.get_position() - header.fntOffset
		while (romFile.get_position() % 4 != 0):
			romFile.store_8(0xFF)
		
		header.fatOffset = romFile.get_position()
		FAT.writeFAT(romFile, rootDir, ovlStartOffsets, ovlEndOffsets)
		header.fatSize = romFile.get_position() - header.fatOffset
		while (romFile.get_position() % 4 != 0):
			romFile.store_8(0xFF)
			
		
		header.iconOffset = romFile.get_position()
		romFile.store_buffer(FileAccess.get_file_as_bytes(dirPath.path_join("banner.bin")))
		
		NitroDirectory.repackFileTree(romFile, dirPath.path_join("data"), rootDir)
		
		romFile.seek(0)
		NitroHeader.updateHeaderChecksum(header)
		NitroHeader.writeHeader(header, romFile)
		
		print("COMPILE COMPLETE?")
		romFile.close()
		reader.close()
	
func addPadding(offset: int) -> int:
	if (offset % 4 != 0):
		return offset + (4 - offset % 4)
	else:
		return offset
		

func getFileSize(path: String) -> int:
	var tmp = FileAccess.open(path, FileAccess.READ)
	var size = tmp.get_length()
	tmp.close()
	return size;
		
###############
# Byte = 8 Bits
# 1 Hexadecimal Digit = 4 Bits
# Word = 16 Bits
#
#
#
#
################


class NitroHeader:
	static var headerValues = ["gameTitle", "gameCode", "makerCode", "unitCode", "encryptionSeedSelect", "deviceCapacity", "reserved1", "dsiFlags", "ndsRegion", "romVersion", "autoStart", "arm9RomOffset", "arm9EntryAddress", "arm9RamAddress", "arm9Size", "arm7RomOffset", "arm7EntryAddress", "Arm7RamAddress", "arm7Size", "fntOffset", "fntSize", "fatOffset", "fatSize", "arm9OverlayOffset", "arm9OverlaySize", "arm7OverlayOffset", "arm7OverlaySize", "port40001A4hNormalCommand", "port40001A4hKey1Command", "iconOffset", "secureAreaChecksum", "secureAreaDelay", "arm9AutoLoad", "arm7AutoLoad", "secureAreaDisable", "usedRomSize", "headerSize", "reserved2", "reserved3", "logo", "logoChecksum", "headerChecksum", "debugRomOffset", "debugSize", "reserved4", "reserved5"]
	
	var gameTitle: String
	var gameCode: String
	var makerCode: String
	var unitCode: int
	var encryptionSeedSelect: int 
	var deviceCapacity: int
	var reserved1: PackedByteArray
	var dsiFlags: int
	var ndsRegion: int
	var romVersion: int
	var autoStart: int
	
	var arm9RomOffset: int
	var arm9EntryAddress: int
	var arm9RamAddress: int
	var arm9Size: int
	
	var arm7RomOffset: int
	var arm7EntryAddress: int
	var arm7RamAddress: int
	var arm7Size: int
	
	var fntOffset: int
	var fntSize: int
	
	var fatOffset: int
	var fatSize: int
	
	var arm9OverlayOffset: int
	var arm9OverlaySize: int

	var arm7OverlayOffset: int
	var arm7OverlaySize: int
	
	var port40001A4hNormalCommand: int
	var port40001A4hKey1Command: int
	
	var iconOffset: int
	
	var secureAreaChecksum: int
	var secureAreaDelay: int
	
	var arm9AutoLoad: int
	var arm7AutoLoad: int
	
	var secureAreaDisable: int
	
	var usedRomSize: int
	var headerSize: int
	
	var reserved2: PackedByteArray
	var reserved3: PackedByteArray
	
	var logo: PackedByteArray
	var logoChecksum: int
	var headerChecksum: int
	
	var debugRomOffset: int
	var debugSize: int
	var debugRamAddress: int
	
	var reserved4: int
	var reserved5: PackedByteArray
	
	static func readHeader(romFile:FileAccess) -> NitroHeader:
		var header = NitroHeader.new()
		header.gameTitle = romFile.get_buffer(12).get_string_from_ascii()
		header.gameCode = romFile.get_buffer(4).get_string_from_ascii()
		header.makerCode = romFile.get_buffer(2).get_string_from_ascii()
		header.unitCode = romFile.get_8()
		header.encryptionSeedSelect = romFile.get_8()
		header.deviceCapacity = romFile.get_8()
		header.reserved1 = romFile.get_buffer(7)
		header.dsiFlags = romFile.get_8()
		header.ndsRegion = romFile.get_8()
		header.romVersion = romFile.get_8()
		header.autoStart = romFile.get_8()
		
		header.arm9RomOffset = romFile.get_32()
		header.arm9EntryAddress = romFile.get_32()
		header.arm9RamAddress = romFile.get_32()
		header.arm9Size = romFile.get_32()

		header.arm7RomOffset = romFile.get_32()
		header.arm7EntryAddress = romFile.get_32()
		header.arm7RamAddress = romFile.get_32()
		header.arm7Size = romFile.get_32()
		
		header.fntOffset = romFile.get_32()
		header.fntSize = romFile.get_32()
		header.fatOffset = romFile.get_32()
		header.fatSize = romFile.get_32()

		header.arm9OverlayOffset = romFile.get_32()
		header.arm9OverlaySize = romFile.get_32()

		header.arm7OverlayOffset = romFile.get_32()
		header.arm7OverlaySize = romFile.get_32()

		header.port40001A4hNormalCommand = romFile.get_32()
		header.port40001A4hKey1Command = romFile.get_32()
		
		header.iconOffset = romFile.get_32()
		header.secureAreaChecksum = romFile.get_16()
		header.secureAreaDelay = romFile.get_16()
		header.arm9AutoLoad = romFile.get_32()
		header.arm7AutoLoad = romFile.get_32()
		header.secureAreaDisable = romFile.get_64()
		header.usedRomSize = romFile.get_32()
		header.headerSize = romFile.get_32()
		header.reserved2 = romFile.get_buffer(40)
		header.reserved3 = romFile.get_buffer(16)
		
		header.logo = romFile.get_buffer(156);
		header.logoChecksum = romFile.get_16();
		header.headerChecksum = romFile.get_16();
		header.debugRomOffset = romFile.get_32();
		header.debugSize = romFile.get_32();
		header.debugRamAddress = romFile.get_32();
		header.reserved4 = romFile.get_32();
		header.reserved5 = romFile.get_buffer(144);
		
		return header
		
	static func writeHeader(header: NitroHeader, romFile: FileAccess) -> void:
		var savedPos = romFile.get_position() + (12)
		romFile.store_buffer(header.gameTitle.to_ascii_buffer());
		romFile.seek(savedPos)
		romFile.store_buffer(header.gameCode.to_ascii_buffer());
		romFile.store_buffer(header.makerCode.to_ascii_buffer());
		romFile.store_8(header.unitCode);
		romFile.store_8(header.encryptionSeedSelect);
		romFile.store_8(header.deviceCapacity);
		romFile.store_buffer(header.reserved1);
		romFile.store_8(header.dsiFlags);
		romFile.store_8(header.ndsRegion);
		romFile.store_8(header.romVersion);
		romFile.store_8(header.autoStart);
		
		romFile.store_32(header.arm9RomOffset);
		romFile.store_32(header.arm9EntryAddress);
		romFile.store_32(header.arm9RamAddress);
		romFile.store_32(header.arm9Size);

		romFile.store_32(header.arm7RomOffset);
		romFile.store_32(header.arm7EntryAddress);
		romFile.store_32(header.arm7RamAddress);
		romFile.store_32(header.arm7Size);

		romFile.store_32(header.fntOffset);
		romFile.store_32(header.fntSize);
		romFile.store_32(header.fatOffset);
		romFile.store_32(header.fatSize);

		romFile.store_32(header.arm9OverlayOffset);
		romFile.store_32(header.arm9OverlaySize);

		romFile.store_32(header.arm7OverlayOffset);
		romFile.store_32(header.arm7OverlaySize);

		romFile.store_32(header.port40001A4hNormalCommand);
		romFile.store_32(header.port40001A4hKey1Command);

		romFile.store_32(header.iconOffset);
		romFile.store_16(header.secureAreaChecksum);
		romFile.store_16(header.secureAreaDelay);
		romFile.store_32(header.arm9AutoLoad);
		romFile.store_32(header.arm7AutoLoad);
		romFile.store_64(header.secureAreaDisable);
		romFile.store_32(header.usedRomSize);
		romFile.store_32(header.headerSize);
		romFile.store_buffer(header.reserved2);
		romFile.store_buffer(header.reserved3);
		
		savedPos = romFile.get_position() + 0x9C
		romFile.store_buffer(header.logo);
		romFile.seek(savedPos)
		romFile.store_16(header.logoChecksum);
		romFile.store_16(header.headerChecksum);
		romFile.store_32(header.debugRomOffset);
		romFile.store_32(header.debugSize);
		romFile.store_32(header.debugRamAddress);
		romFile.store_32(header.reserved4);
		romFile.store_buffer(header.reserved5);

		pass

	static func updateHeaderChecksum(header: NitroHeader) -> void:
		var tmpHeader: PackedByteArray
		tmpHeader.resize(0x8000)
		var byteOffset: int = 0
		var b = 0
		var toPut = header.gameCode.to_ascii_buffer()
		while (b < toPut.size()):
			tmpHeader.encode_u8(byteOffset, toPut[b])
			b += 1
			byteOffset += 1
		b = 0
		toPut = header.gameTitle.to_ascii_buffer()
		while (b < toPut.size()):
			tmpHeader.encode_u8(byteOffset, toPut[b])
			b += 1
			byteOffset += 1
		b = 0	
		toPut = header.makerCode.to_ascii_buffer()
		while (b < toPut.size()):
			tmpHeader.encode_u8(byteOffset, toPut[b])
			b += 1
			byteOffset += 1
		tmpHeader.encode_u32(byteOffset, header.arm9RomOffset)
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm9EntryAddress);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm9RamAddress);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm9Size);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm7RomOffset);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm7EntryAddress);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm7RamAddress);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm7Size);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.fntOffset);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.fntSize);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.fatOffset);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.fatSize);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm9OverlayOffset);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm9OverlaySize);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm7OverlayOffset);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm7OverlaySize);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.port40001A4hNormalCommand);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.port40001A4hKey1Command);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.iconOffset);
		byteOffset += 4
		tmpHeader.encode_u16(byteOffset, header.secureAreaChecksum);
		byteOffset += 2
		tmpHeader.encode_u16(byteOffset, header.secureAreaDelay);
		byteOffset += 2
		tmpHeader.encode_u32(byteOffset, header.arm9AutoLoad);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.arm7AutoLoad);
		byteOffset += 4
		tmpHeader.encode_u64(byteOffset, header.secureAreaDisable);
		byteOffset += 8
		tmpHeader.encode_u32(byteOffset, header.usedRomSize);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.headerSize);
		byteOffset += 4
		b = 0
		toPut = header.reserved2
		while (b < toPut.size()):
			tmpHeader.encode_u8(byteOffset, toPut[b])
			b += 1
			byteOffset += 1
		b = 0
		toPut = header.reserved3
		while (b < toPut.size()):
			tmpHeader.encode_u8(byteOffset, toPut[b])
			b += 1
			byteOffset += 1
		b = 0
		toPut = header.logo
		while (b < toPut.size()):
			tmpHeader.encode_u8(byteOffset, toPut[b])
			b += 1
			byteOffset += 1
		tmpHeader.encode_u16(byteOffset, header.logoChecksum);
		byteOffset += 2
		tmpHeader.encode_u16(byteOffset, header.headerChecksum);
		byteOffset += 2
		tmpHeader.encode_u32(byteOffset, header.debugRomOffset);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.debugSize);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.debugRamAddress);
		byteOffset += 4
		tmpHeader.encode_u32(byteOffset, header.reserved4)
		byteOffset += 4
		b = 0
		toPut = header.reserved5
		while (b < toPut.size()):
			tmpHeader.encode_u8(byteOffset, toPut[b])
			b += 1
			byteOffset += 1
		tmpHeader = tmpHeader.slice(0, byteOffset)
		
		header.headerChecksum = CRC.calculateCRC(tmpHeader.slice(0, 0x15e))
		header.logoChecksum = CRC.calculateCRC(tmpHeader.slice(0xc0, 0x15c))
		header.secureAreaChecksum = CRC.calculateCRC(tmpHeader.slice(header.arm9RomOffset, 0x8000 - header.arm9RomOffset))
		tmpHeader.clear()
		pass

	static func compareHeader(headerA: NitroHeader, headerB: NitroHeader):
		var i = 0
		while (i < NitroHeader.headerValues.size()):
			var property = NitroHeader.headerValues[i]
			var aValue = headerA.get(property)
			var bValue = headerB.get(property)
			if (aValue != bValue):
				print(property + " value differs!")
				print("A: " + str(aValue))
				print("B: " + str(bValue))
			i += 1
		pass

class NitroParent:
	var name: String

class NitroDirectory extends NitroParent: 
	var id: int
	var parent: NitroDirectory
	var fileList: Array[NitroParent]
		#get:
			#fileList.sort_custom(sortNameAscending)
			#return fileList
	var directoryList: Array[NitroParent]
		#get:
			#fileList.sort_custom(sortNameAscending)
			#return directoryList
	
	static var currentDirId: int
	static var fileId: int
	static var currentOffset: int
		
	func _init(n: String, i: int, p: NitroDirectory):
		name = n
		id = i
		parent = p
		
	func toString() -> String:
		return "NitroDirectory{name='" + name + ", id=" + str(id) + "}"
		
	static func loadDirFNT(p: NitroDirectory, stream: FileAccess, origin: int, startOffset: Dictionary, endOffset: Dictionary) -> void:
		var position: int = stream.get_position()
		stream.seek(origin + (8 * (p.id & 0xFFF)) )
		
		var subTableOffset: int = stream.get_32()
		var firstFileId: int = stream.get_16()
		
		stream.seek(origin + subTableOffset)
		
		var header: int = stream.get_8()
		
		while (header & 0x7F != 0):
			var nameBytes: String = stream.get_buffer(header & 0x7F).get_string_from_ascii()
			if (header > 0x7F):
				var newID: int = stream.get_16()
				var newDir: NitroDirectory = NitroDirectory.new(nameBytes, newID, p)
				p.directoryList.append(newDir)
				loadDirFNT(newDir, stream, origin, startOffset, endOffset)
			else:
				var f = NitroFile.new(nameBytes, firstFileId, startOffset[firstFileId], endOffset[firstFileId] - startOffset[firstFileId], p)
				p.fileList.append(f)
				firstFileId += 1
			header = stream.get_8()
		
		stream.seek(position)
		pass
		
	static func loadDirA(currPath: String, p: NitroDirectory, currDirId: int, firstFileId: int, currOffset: int) -> void:
		NitroDirectory.currentDirId = currDirId
		NitroDirectory.fileId = firstFileId
		if (currOffset % 4 != 0):
			currOffset += (4 - (currOffset % 4))
		NitroDirectory.currentOffset = currOffset
		loadDirB(currPath, p)
		
	static func sortNameAscending(a: NitroParent, b: NitroParent) -> bool:
		if (a.name.nocasecmp_to(b.name)):
			return false;
		else:
			return true
		
	static func loadDirB(currPath: String, p: NitroDirectory) -> void:
		var currDir = DirAccess.open(currPath)
		var dirList = currDir.get_directories()
		var files = currDir.get_files()
		
		if (!dirList.is_empty()):
			var i = 0
			while (i < dirList.size()):
				NitroDirectory.currentDirId += 1
				var newDir: NitroDirectory = NitroDirectory.new(dirList[i], NitroDirectory.currentDirId, p)
				p.directoryList.append(newDir)
				loadDirB(currPath.path_join(dirList[i]), newDir)
				
				i += 1
		
		if (!files.is_empty()):
			files.sort()
			var i = 0
			while (i < files.size()):
				var temp = FileAccess.open(currPath.path_join(files[i]), FileAccess.READ)
				var size: int = temp.get_length()
				temp.close()
				p.fileList.append(NitroFile.new(files[i], NitroDirectory.fileId, currentOffset, size, p))
				fileId += 1
				currentOffset += size
				if (currentOffset % 4 != 0):
					currentOffset += (4 - (currentOffset % 4))
				i += 1
		pass
		
	static func unpackFileTree(romFile: FileAccess, currPath: String, rootDir: NitroDirectory) -> void:
		var i: int = 0
		while (i < rootDir.directoryList.size()):
			var dir: NitroDirectory = rootDir.directoryList[i]
			var subDir: String = currPath.path_join(dir.name)
			if (!FileAccess.file_exists(subDir)):
				DirAccess.make_dir_absolute(subDir)
			unpackFileTree(romFile, subDir, dir)
			i += 1
		i = 0
		while (i < rootDir.fileList.size()):
			var f: NitroFile = rootDir.fileList[i]
			if (!FileAccess.file_exists(currPath.path_join( f.name ) ) ):
				var newFile = FileAccess.open(currPath.path_join( f.name ), 7)
				romFile.seek(f.offset)
				newFile.store_buffer(romFile.get_buffer(f.size))
				newFile.close()
			i += 1
		pass
		
	static func repackFileTree(romFile: FileAccess, currPath: String, rootDir: NitroDirectory) -> void:
		var i: int = 0
		while (i < rootDir.directoryList.size()):
			repackFileTree(romFile, currPath.path_join(rootDir.directoryList[i].name), rootDir.directoryList[i])
			i += 1
			
		i = 0
		while (i < rootDir.fileList.size()):
			var f: NitroFile = rootDir.fileList[i]
			if (FileAccess.file_exists( currPath.path_join(f.name) ) ):
				if (f.offset != romFile.get_position()):
					print("***WARNING***")
					print(f.name + " real offset differs from the assumed one!")
					print("Assumed: " + str(f.offset) + " Real: " + str(romFile.get_position()))
					f.offset = romFile.get_position()
				romFile.store_buffer(FileAccess.get_file_as_bytes(currPath.path_join(f.name)))
				while (romFile.get_position() % 4 != 0):
					romFile.store_8(0xFF)
			else:
				# FILE DOES NOT EXIST
				pass
			i += 1

class NitroFile extends NitroParent:
	var id: int
	var offset: int
	var size: int
	var parent: NitroDirectory
	
	func _init(n: String, i: int, os: int, s: int, p: NitroDirectory):
		id = i
		offset = os
		size = s
		name = n
		parent = p
	
	func toString() -> String:
		return "NitroFile{Name:" + name + " Id:" + str(id) + "}"

class NitroOverLay:
	var id: int
	var ramAddress: int
	var ramSize: int
	var bssSize: int
	var stInitStart: int
	var stInitEnd: int
	var fileId: int
	var reserved: int
	var startOffset: int
	var endOffset: int

class FNT:
	static var subByteOffset: int
	static var mainByteOffset: int
	static var fntMainTable: PackedByteArray
	static var fntSubTable: PackedByteArray
	
	static func writeFNT(romFile: FileAccess, rootDir: NitroDirectory) -> void:
		if (rootDir.id == 0xf000):
			var s = getDirNumA(rootDir) + 1
			var size = s * 8
			fntMainTable = PackedByteArray()
			fntMainTable.resize(size)
			size = getSubTableSizeA(rootDir)
			fntSubTable = PackedByteArray()
			fntSubTable.resize(size)
			
			mainByteOffset = 0
			subByteOffset = 0
			fntMainTable.encode_u32(mainByteOffset, fntMainTable.size())
			mainByteOffset += 4
			fntMainTable.encode_u16(mainByteOffset, getFirstFileId(rootDir))
			mainByteOffset += 2
			fntMainTable.encode_u16(mainByteOffset, s)
			mainByteOffset += 2
			
			writeFNTB(rootDir)
			
			romFile.store_buffer(fntMainTable)
			romFile.store_buffer(fntSubTable)
			
	static func writeFNTB(dir: NitroDirectory) -> void:
		var i = 0;
		while (i < dir.directoryList.size()):
			var d = dir.directoryList[i]
			fntSubTable.encode_u8(subByteOffset, 128 + d.name.length())
			subByteOffset += 1
			putSub(d.name.to_ascii_buffer())
			fntSubTable.encode_u16(subByteOffset, d.id)
			subByteOffset += 2
			i += 1
		i = 0
		while (i < dir.fileList.size()):
			var f = dir.fileList[i]
			fntSubTable.encode_u8(subByteOffset, f.name.length())
			subByteOffset += 1
			putSub(f.name.to_ascii_buffer())
			i += 1
		fntSubTable.encode_u8(subByteOffset, 0)
		subByteOffset += 1
		i = 0
		while (i < dir.directoryList.size()):
			var d = dir.directoryList[i]
			fntMainTable.encode_u32(mainByteOffset, fntMainTable.size() + subByteOffset)
			mainByteOffset += 4
			fntMainTable.encode_u16(mainByteOffset, getFirstFileId(d))
			mainByteOffset += 2
			fntMainTable.encode_u16(mainByteOffset, d.parent.id)
			mainByteOffset += 2
			writeFNTB(d)
			i += 1
		
	static func putSub(toPut: PackedByteArray) -> void:
		var b = 0
		while (b < toPut.size()):
			fntSubTable.encode_u8(subByteOffset, toPut[b])
			b += 1
			subByteOffset += 1
		
	static func calculateFNTSize(path: String) -> int:
		return (getDirNumB(path) + 1) * 8 + getSubTableSizeB(path)
		
		
	static func getDirNumA(d: NitroDirectory) -> int:
		var n: int = d.directoryList.size()
		var i : int = 0;
		while (i < d.directoryList.size()):
			n += getDirNumA(d.directoryList[i])
			i += 1
		return n

	static func getDirNumB(path: String) -> int:
		
		if (DirAccess.dir_exists_absolute(path)):
			var currDir = DirAccess.open(path)
			var dirList = currDir.get_directories()
			var n = dirList.size()
			var i = 0;
			while (i < dirList.size()):
				n += getDirNumB(path.path_join(dirList[i]))
				i += 1
			
			return n
		else:
			
			return 0
		
	static func getFirstFileId(d: NitroDirectory) -> int:
		if (d.fileList.size() > 0):
			return d.fileList[0].id
		else:
			return d.directoryList[0].id
		
	static func getSubTableSizeA(curr: NitroDirectory) -> int:
		var a: int = 0
		var i: int = 0
		while (i < curr.directoryList.size()):
			a += curr.directoryList[i].name.length() + 3
			i += 1
		i = 0
		while (i < curr.fileList.size()):
			a += curr.fileList[i].name.length() + 1
			i += 1
		a += 1
		i = 0
		while (i < curr.directoryList.size()):
			a += getSubTableSizeA(curr.directoryList[i])
			i += 1
		return a
		
	static func getSubTableSizeB(curr: String) -> int:
		var a: int = 0
		if (DirAccess.dir_exists_absolute(curr)):
			var currDir = DirAccess.open(curr)
			var dirList = currDir.get_directories()
			var i: int = 0
			while (i < dirList.size()):
				a += dirList[i].length() + 3
				i += 1
			var fileList = currDir.get_files()
			i = 0
			while (i < fileList.size()):
				a += fileList[i].length() + 1
				i += 1
			a += 1
			i = 0
			while (i < dirList.size()):
				a += getSubTableSizeB(curr.path_join(dirList[i]))
				i += 1
			return a
		else:
			return a

class FAT:
	static func writeFAT(romFile: FileAccess, rootDir: NitroDirectory, ovlStartOffsets: Array[int], ovlEndOffsets: Array[int]) -> void:
		if (rootDir.id == 0xf000):
			var i = 0
			while (i < ovlStartOffsets.size()):
				romFile.store_32(ovlStartOffsets[i])
				romFile.store_32(ovlEndOffsets[i])
				i += 1
			writeFATB(romFile, rootDir)
			
	static func writeFATB(romFile: FileAccess, rootDir: NitroDirectory) -> void:
		var i = 0
		while (i < rootDir.directoryList.size()):
			writeFATB(romFile, rootDir.directoryList[i])
			i += 1
		i = 0
		while (i < rootDir.fileList.size()):
			romFile.store_32(rootDir.fileList[i].offset)
			romFile.store_32(rootDir.fileList[i].offset + rootDir.fileList[i].size)
			i += 1

	static func calculateFATSize(path: String) -> int:
		if (DirAccess.dir_exists_absolute(path)):
			var dir = DirAccess.open(path)
			var n: int = dir.get_files().size() * 8
			var i = 0;
			while (i < dir.get_directories().size()):
				n += calculateFATSize(path.path_join(dir.get_directories()[i]))
				i += 1
			return n
		else:
			return 0;

#########
# https://github.com/snksoft/java-crc/blob/master/src/main/java/com/github/snksoft/crc/CRC.java
#########
class CRC:
	const width: int = 16
	const polynomial: int = 0x8005
	const reflectIn: bool = true
	const reflectOut: bool = true
	const init: int = 0x0000
	const finalXor: int = 0x0
	
	static func calculateCRC(data: PackedByteArray) -> int:
		var curValue: int = init
		var topBit: int = 1 << (width - 1)
		var mask: int = (topBit << 1) - 1
		var end: int = data.size()
		var i = 0
		while (i < end):
			var curByte = data[i] & 0x00FF
			if (reflectIn):
				curByte = reflect(curByte, 8)
			i += 1
			
			var j: int = 0x80
			while (j != 0):
				var bit: int = curValue & topBit
				curValue <<= 1
				
				if ((curByte & j) != 0):
					bit ^= topBit
					
				if (bit != 0):
					curValue ^= polynomial
				j >>= 1
		
		if (reflectOut):
			curValue = reflect(curValue, width)
			
		curValue = curValue ^ finalXor
		
		return curValue & mask
		
	static func reflect(orig: int, count: int) -> int:
		var ret: int = orig
		var i = 0;
		while (i < count):
			var srcbit: int = 1 << i
			var dstbit = 1 << (count - i - 1)
			if ((orig & srcbit) != 0):
				ret |= dstbit
			else:
				ret = ret & (~dstbit)
			i += 1
		return ret
