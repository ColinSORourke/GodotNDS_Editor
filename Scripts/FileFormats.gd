extends Node

# NTR Header
class ntrHeader:
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

# NCLR, NPCR Palette
# https://github.com/turtleisaac/Nds4j/blob/main/src/main/java/io/github/turtleisaac/nds4j/images/Palette.java
class Palette:
	const TTLPMagic = 0x504C5454
	
	const NCLRMagic = 0x4E434C52
	const palHeader: PackedByteArray = [0x54, 0x54, 0x4C, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00]
	const IRColor = Color(72, 144, 160)
	
	var magic: int
	var sectionSize: int
	enum bitType {NONE = 0, FOUR_BPP = 4, EIGHT_BPP = 8}
	var bitDepth: bitType
	var compNum: int
	
	var colors: Array[Color] = []
	var ir: bool = false
	
	var myImage: Image
	
	func _init() -> void:
		# I don't know what this variable is! Could cause problem
		compNum = 10
	
	func initNum(num: int) -> void:
		var i = 0
		var mult = 256/num
		while(i < num):
			var j = (i * mult) % 256
			var nColor = Color(0, 0, 0)
			nColor.r8 = j
			nColor.b8 = j
			nColor.g8 = j
			colors.append(nColor)
			i += 1
		
	func initFromBytes(bytes: PackedByteArray) -> void:
		magic = bytes.decode_u32(16)
		if (magic != TTLPMagic):
			print("Invalid Palette, wrong magic")
			print(String.num_int64(magic, 16))
			return
		if (bytes.size() % 2 != 0):
			print("Invalid palette, File Size not multiple of two")
			return
		sectionSize = bytes.decode_u32(20)
		if (bytes.decode_u16(24) == 3):
			bitDepth = bitType.FOUR_BPP
		else:
			bitDepth = bitType.EIGHT_BPP
		
		compNum = bytes.decode_u8(26)
		var pltLength: int = bytes.decode_u32(32)
		var startOffset: int = bytes.decode_u32(36)
		
		if (pltLength == 0 || pltLength > sectionSize):
			pltLength = sectionSize - 0x18
			
		var numColors: int = 256
		if (pltLength/2 < numColors):
			numColors = pltLength/2
			
		var currInd: int = 0x18 + startOffset
		var i = 0
		while(i < numColors):
			colors.append(bgr555toColor(bytes.decode_u8(currInd), bytes.decode_u8(currInd + 1)))
			currInd += 2
			i += 1
		if (colors[i-1] == IRColor):
			ir = true

	func initFromJasc(jasc: PackedStringArray) -> void:
		if(jasc[0] != "JASC-PAL"):
			# NOT A JASC PALETTE
			return
		var i = 3
		while (i < jasc.size() - 1):
			var nColor = Color()
			var rgb = jasc[i].split(" ")
			nColor.r8 = rgb[0].to_int()
			nColor.g8 = rgb[1].to_int()
			nColor.b8 = rgb[2].to_int()
			colors.append(nColor)
			i += 1
		
	func toBytes() -> PackedByteArray:
		var returnBytes: PackedByteArray = []
		var size: int = colors.size() * 2
		returnBytes.resize(16)
		returnBytes.encode_u32(0, NCLRMagic)
		returnBytes.encode_u16(4, 0xFEFF)
		returnBytes.encode_u16(6, 0x0100)
		returnBytes.encode_u32(8, size + 40)
		returnBytes.encode_u16(12, 0x10)
		returnBytes.encode_u16(14, 1)
		returnBytes.append_array(palHeader)
		returnBytes.encode_u32(20, size + 24)
		if (bitDepth == bitType.FOUR_BPP):
			returnBytes.encode_u16(24, 0x3)
		else:
			returnBytes.encode_u16(24, 0x4)
		returnBytes.encode_u8(26, compNum)
		returnBytes.encode_u32(32, size)
		
		var i = 0
		while (i < colors.size()):
			returnBytes.append_array(colorToBgr555(colors[i]))
			i += 1
		return returnBytes

	func toImage() -> Image:
		var squareSize: int = 1
		while(squareSize * squareSize < colors.size()):
			squareSize += 1
		var myImage = Image.create_empty(squareSize, squareSize, false, Image.FORMAT_RGBA8)
		var i = 0
		while(i < colors.size()):
			myImage.set_pixel(i / squareSize, i % squareSize, colors[i])
			i += 1
		return myImage

	# JASC-Palette
	# https://liero.nl/lierohack/docformats/other-jasc.html
	func toJascPal() -> PackedStringArray:
		var returnArray: PackedStringArray = []
		returnArray.append("JASC-PAL")
		returnArray.append("0100")
		returnArray.append("256")
		var i = 0
		while (i < colors.size()):
			returnArray.append(colorToJascStr(colors[i]))
			i += 1
		return returnArray

	static func bgr555toColor(byte1: int, byte2: int) -> Color:
		var bgr: int = ((byte2 & 0xff) << 8) | (byte1 & 0xff)
		var retColor = Color()
		retColor.r8 = (bgr & 0x001F) << 3;
		retColor.g8 = ((bgr & 0x03E0) >> 2);
		retColor.b8 = ((bgr & 0x7C00) >> 7);
		return retColor

	static func colorToBgr555(c: Color) -> PackedByteArray:
		var colorBytes: PackedByteArray = [0x00, 0x00]
		var r: int = c.r8 / 8
		var g: int = int(c.g8 / 8) << 5
		var b: int = int(c.b8 / 8) << 10
		var bgr: int = r + g + b
		colorBytes[0] = bgr & 0xFF
		colorBytes[1] = (bgr >> 8) & 0xFF
		print
		return colorBytes

	static func colorToJascStr(c: Color) -> String:
		var retStr = ""
		retStr += str(c.r8) + " "
		retStr += str(c.g8) + " "
		retStr += str(c.b8)
		return retStr

class NCGR:
	const ncgrMagic: int = 0x4E434752 # "NCGR"
	const charMagic: int = 0x43484152 # "CHAR"
	
	var myBytes: PackedByteArray
	
	var header: ntrHeader
	
	var sectionSize: int
	var nTilesX: int
	var nTilesY: int
	var bitDepth: Palette.bitType
	var numTiles: int
	
	var tiled: bool
	var tileSize: int
	var scanned: bool
	var frontToBack: bool = true
	
	var sopcSize: int
	var sopcCharSize: int
	var sopcCharNum: int
	
	var encVal: int = 0
	
	func process(bytes: PackedByteArray):
		myBytes = bytes
		header = ntrHeader.new()
		header.process(bytes)
		if (bytes.decode_u32(16) != charMagic):
			print("Invalid NCGR")
			return
		sectionSize = bytes.decode_u32(20)
		nTilesY = bytes.decode_u16(24)
		nTilesX = bytes.decode_u16(26)
		match bytes.decode_u32(28):
			3:
				bitDepth = 4
			4:
				bitDepth = 8
			_:
				bitDepth = 1
		tiled = bytes.decode_u32(36) * 0xFF == 0x0
		scanned = bytes.decode_u8(36) == 1
		tileSize = bytes.decode_u32(40)
		numTiles = tileSize / bitDepth
		print(numTiles)
	
		if (nTilesX != 0xFFFF):
			nTilesX *= 8
			nTilesY *= 8
		
		if (header.nSections == 2 && 48 + tileSize < bytes.size()):
			sopcSize = bytes.decode_u32(48 + tileSize + 4)
			sopcCharSize = bytes.decode_u16(48 + tileSize + 12)
			sopcCharNum = bytes.decode_u16(48 + tileSize + 14)

		if (nTilesX == 0xFFFF):
			var square: float = sqrt(float(numTiles*8))
			print(square)
			if (is_equal_approx(square, roundf(square))):
				nTilesX = square
				nTilesY = square
			else:
				nTilesX = min(numTiles*8, 0x100)
				nTilesY = numTiles*8/nTilesX 
			if (nTilesX == 0):
				nTilesX = 1
			if (nTilesY == 0):
				nTilesY == 1

	func convertFromScannedFBPP(image: IndexedImage) -> void:
		image.width = nTilesX
		image.height = nTilesY
		image.emptyPixels()
		var imageSection: PackedByteArray = myBytes.slice(48)
		
		encVal = 0
		var data: Array[int] = []
		var i: int = 0
		var wh: int = image.width * image.height
		while (i < wh/4):
			data.append(imageSection.decode_u16(i*2))
			i += 1
		
		if (frontToBack):
			encVal = data[0]
			i = 0
			while(i < data.size()):
				data[i] = data[i] ^ (encVal & 0xFFFF)
				encVal *= 1103515245
				encVal += 24691
				i += 1
		else:
			encVal = data[data.size() - 1]
			i = data.size() - 1
			while (i >= 0):
				data[i] = data[i] ^ (encVal & 0xFFFF);
				encVal *= 1103515245;
				encVal += 24691;
				i -= 1
				
		i = 0
		while(i < wh/4):
			var j = 0
			while (j < 4):
				var row = (i*4 + j) / image.width
				var col = (i*4 + j) % image.width
				image.setPixel(col, row, (data[i] >> j*4) & 0xf)
				j += 1
			i += 1
	
	func convertFromScannedEBPP(image: IndexedImage) -> void:
		image.width = nTilesX
		image.height = nTilesY
		image.emptyPixels()
		var imageSection: PackedByteArray = myBytes.slice(48)
	
		encVal = 0
		
		var data: Array[int] = []
		var i: int = 0
		var wh: int = image.width * image.height
		while (i < wh/4):
			data.append(imageSection.decode_u16(i*2))
			i += 1
		
		if (frontToBack):
			encVal = data[0]
			i = 0
			while(i < data.size()):
				data[i] = data[i] ^ (encVal & 0xFFFF)
				encVal *= 1103515245
				encVal += 24691
				i += 1
		else:
			encVal = data[data.size() - 1]
			i = data.size() - 1
			while (i >= 0):
				data[i] = data[i] ^ (encVal & 0xFFFF);
				encVal *= 1103515245;
				encVal += 24691;
				i -= 1
				
		i = 0
		while(i < wh/2):
			var j = 0
			while (j < 2):
				var row = (i*2 + j) / image.width
				var col = (i*2 + j) % image.width
				image.setPixel(col, row, (data[i] >> j*8) & 0xff)
				j += 1
			i += 1
	
	class ChunkManager:
		var TilesSoFar: int = 0
		var RowsSoFar: int = 0
		var ChunkStartX: int = 0
		var ChunkStartY: int = 0
		
		var rows: int = 0
		var cols: int = 0
		
		func _init(r: int, c: int):
			rows = r
			cols = c
		
		func advance(wide: int) -> void:
			TilesSoFar += 1
			if (TilesSoFar == cols):
				TilesSoFar = 0
				RowsSoFar += 1
				if (RowsSoFar == rows):
					RowsSoFar = 0
					ChunkStartX += 1
					if (ChunkStartX == wide):
						ChunkStartX = 0
						ChunkStartY += 1
	
		func getComponentY(mult: int, add: int) -> int:
			return ((ChunkStartY * rows + RowsSoFar) * mult) + add
			
		func getComponentX(mult: int, add: int) -> int:
			return ((ChunkStartX * cols + TilesSoFar) * mult) + add
			
		func printChunk() -> void:
			print("CurrChunk: " + str(ChunkStartX) +","+ str(ChunkStartY))
	
	func convertFromTileFBPP(image: IndexedImage) -> void:
		image.width = nTilesX
		image.height = nTilesY
		image.emptyPixels()
		var imageSection: PackedByteArray = myBytes.slice(48)
		
		var writtenPixels: Array[Vector2i] = []
		
		var chunkMan: ChunkManager = ChunkManager.new(1, 1)
		var chunksWide: int = (image.width / 8)
		var pitch: int = image.width / 2
		
		var i: int = 0
		var idx: int = 0
		while(i < numTiles/8):
			var j = 0
			while(j < 8):
				var idxComponentY = chunkMan.getComponentY(8, j)
				var k = 0
				while (k < 4):
					var idxComponentX: int = chunkMan.getComponentX(4, k)
					var compositeIdx: int = 2 * (idxComponentY * pitch + idxComponentX)
					var destX: int = compositeIdx % image.width
					var destY: int = compositeIdx / image.width
					var pixelPair: int = imageSection[idx]
					idx += 1
					var pixelLeft: int = pixelPair & 0xF
					var pixelRight: int = pixelPair >> 4 & 0xF
					
					if (destX +  1 >= image.width || destY >= image.height):
						print("Something has gone horribly wrong")
						return
					
					image.setPixel(destX, destY, pixelLeft)
					image.setPixel(destX + 1, destY, pixelRight)
					k += 1
				j += 1
			chunkMan.advance(chunksWide)
			i += 1
	
	func convertFromTileEBPP(image: IndexedImage) -> void:
		image.width = nTilesX
		image.height = nTilesY
		image.emptyPixels()
		var imageSection: PackedByteArray = myBytes.slice(48)
		
		var chunkMan: ChunkManager = ChunkManager.new(1, 1)
		var chunksWide: int = (image.width / 8) / chunkMan.cols
		var pitch: int = image.width / 2
		
		var i: int = 0
		var idx: int = 0
		while(i < numTiles):
			var j = 0
			while(j < 8):
				var idxComponentY = chunkMan.getComponentY(8,j)
				var k = 0
				while (k < 8):
					var idxComponentX: int = chunkMan.getComponentX(8,k)
					var compositeIdx: int = 2 * (idxComponentY * pitch + idxComponentX)
					var destX: int = compositeIdx % image.width
					var destY: int = compositeIdx / image.width
					var pixel: int = imageSection[idx]
					idx += 1
					
					if (destX +  1 >= image.width || destY >= image.height):
						print("Something has gone horribly wrong")
						return
					
					image.setPixel(destX, destY, pixel)
					k += 1
				j += 1
			chunkMan.advance(chunksWide)
			i += 1
	
	func setImage(image: IndexedImage):
		if (scanned && bitDepth == 4):
			convertFromScannedFBPP(image)
		elif(scanned):
			convertFromScannedEBPP(image)
		elif(bitDepth == 4):
			convertFromTileFBPP(image)
		else:
			convertFromTileEBPP(image)

# NCLR, NPCR Palette
# https://github.com/turtleisaac/Nds4j/blob/main/src/main/java/io/github/turtleisaac/nds4j/images/IndexedImage.java
class IndexedImage:
	
	const paletteChunkHeader: PackedByteArray = [0x50,0x4C,0x54,0x45]
	const dataChunkHeader: PackedByteArray = [0x49,0x44,0x41,0x54]
	const imageChunkHeader: PackedByteArray = [0x49,0x48,0x44,0x52]
	const endChunkHeader: PackedByteArray = [0x49,0x45,0x4E,0x44]
	const PNGHeader: PackedByteArray = [0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]
	const ncgrMagic: int = 0x4E434752 # "NCGR"
	const charMagic: int = 0x43484152 # "CHAR"
	
	var myHeader: ntrHeader
	
	var myBytes: PackedByteArray
	var myImage: Image
	
	var width: int
	var height: int
	var myPalette: Palette
	
	static func isNCGR(bytes: PackedByteArray) -> bool:
		var header = ntrHeader.new()
		header.process(bytes)
		return header.magic == IndexedImage.ncgrMagic
	
	func setPixel(x: int, y: int, p: int) -> void:
		myImage.set_pixel(x, y, myPalette.colors[p])
	
	func emptyPixels() -> void:
		myImage = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
		
	func toImage() -> Image:
		return myImage
	
	func initFromPNG(path: String, justPal: bool = false):
		var paletteIndex: int
		var dataIndex: int
		myBytes = FileAccess.get_file_as_bytes(path)
		if (myBytes.slice(0, 8) != PNGHeader):
			print("NOT A PNG")
			return
		
		var currInd = 0
		while (currInd < myBytes.size() - 4):
			var currFour: PackedByteArray = myBytes.slice(currInd, currInd + 4)
			if (currFour == paletteChunkHeader):
				paletteIndex = currInd
			if (currFour == dataChunkHeader):
				dataIndex = currInd
			if (currFour == endChunkHeader):
				break
			currInd += 1
			
		width = myBytes.decode_u32(16)
		height = myBytes.decode_u32(20)
		myPalette = Palette.new()
		
		myPalette.bitDepth = myBytes.decode_u8(24)
		var valid: bool = true && myBytes.decode_u8(25) == 3
		valid = valid && myBytes.decode_u8(26) == 0
		valid = valid && myBytes.decode_u8(27) == 0
		valid = valid && myBytes.decode_u8(28) <= 1
		
		if (!valid):
			print("PNG IMPROPERLY FORMATTED")
			return
	
		var chunkLength: int = swapEndianInt32(myBytes.decode_u32(paletteIndex - 4))
		var i = 0
		while (i < chunkLength/3):
			var nColor: Color = Color()
			var cVal: int = myBytes.decode_u8(paletteIndex + 4 + i*3)
			nColor.r8 = cVal
			cVal = myBytes.decode_u8(paletteIndex + 4 + i*3 + 1)
			nColor.g8 = cVal
			cVal = myBytes.decode_u8(paletteIndex + 4 + i*3 + 2)
			nColor.b8 = cVal
			myPalette.colors.append(nColor)
			i += 1
		
		if (justPal):
			# Done here!
			return
	
	func initFromNCGR(bytes: PackedByteArray):
		var myNCGR = NCGR.new()
		myNCGR.process(bytes)
		myNCGR.setImage(self)
	
	static func swapEndianInt32(i: int) -> int:
		var b1 = (i & 0xFF000000) >> 24
		var b2 = (i & 0x00FF0000) >> 8
		var b3 = (i & 0x0000FF00) << 8
		var b4 = (i & 0x000000FF) << 24
		return b1 | b2 | b3 | b4
