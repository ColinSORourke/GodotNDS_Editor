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
		
	func write() -> PackedByteArray:
		var retBytes: PackedByteArray = []
		retBytes.resize(16)
		retBytes.encode_u32(0, magic)
		retBytes.encode_u32(4, constant)
		retBytes.encode_u32(8, fileSize)
		retBytes.encode_u16(12, headerSize)
		retBytes.encode_u16(14, nSections)
		return retBytes

# NCLR, NPCR Palette
# https://github.com/turtleisaac/Nds4j/blob/main/src/main/java/io/github/turtleisaac/nds4j/images/Palette.java
class Palette:
	const TTLPMagic = 0x504C5454
	
	const NCLRMagic = 0x4E434C52
	const palHeader: PackedByteArray = [0x54, 0x54, 0x4C, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00]
	const IRColor = Color(72, 144, 160)
	
	var magic: int
	var sectionSize: int
	var bitDepth: int
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
		bitDepth = 4
		
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
		bitDepth = bytes.decode_u16(24)
		if (bitDepth == 3):
			bitDepth = 4
		
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
		returnBytes.encode_u16(24, bitDepth)
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
		return colorBytes

	static func colorToJascStr(c: Color) -> String:
		var retStr = ""
		retStr += str(c.r8) + " "
		retStr += str(c.g8) + " "
		retStr += str(c.b8)
		return retStr

# NCGR
# https://github.com/AdAstra-LD/DS-Pokemon-Rom-Editor
class NCGR:
	const ncgrMagic: int = 0x4E434752 # "NCGR"
	const charMagic: int = 0x43484152 # "CHAR"
	const charHeader: PackedByteArray = [0x52, 0x41, 0x48, 0x43, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00]
	
	var myBytes: PackedByteArray
	
	var header: ntrHeader
	
	var sectionSize: int
	var nTilesX: int
	var nTilesY: int
	var bitDepth: int
	var numTiles: int
	
	var tiled: bool
	var tileSize: int
	var scanned: bool
	var frontToBack: bool = true
	
	var sopcSize: int
	var sopcCharSize: int
	var sopcCharNum: int
	
	var encVal: int = -1
	var vram: bool = false
	var mappingType: int = 32
	
	static func isNCGR(bytes: PackedByteArray) -> bool:
		var header = ntrHeader.new()
		header.process(bytes)
		return header.magic == ncgrMagic
	
	func process(bytes: PackedByteArray) -> void:
		myBytes = bytes
		header = ntrHeader.new()
		header.process(bytes)
		if (bytes.decode_u32(16) != charMagic):
			print("Invalid NCGR")
			return
		sectionSize = bytes.decode_u32(20)
		match bytes.decode_u16(22):
			0:
				mappingType = 32
			0x10:
				mappingType = 64
			0x20:
				mappingType = 128
			0x30: 
				mappingType = 256
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
		vram = bytes.decode_u8(37) == 1
		tileSize = bytes.decode_u32(40)
		numTiles = tileSize / bitDepth
	
		if (nTilesX != 0xFFFF):
			nTilesX *= 8
			nTilesY *= 8
		
		if (header.nSections == 2 && 48 + tileSize < bytes.size()):
			sopcSize = bytes.decode_u32(48 + tileSize + 4)
			sopcCharSize = bytes.decode_u16(48 + tileSize + 12)
			sopcCharNum = bytes.decode_u16(48 + tileSize + 14)

		if (nTilesX == 0xFFFF):
			var square: float = sqrt(float(numTiles*8))
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

	func decrypt(arr: Array[int]) -> Array[int]:
		if (frontToBack):
			encVal = arr[0]
			var i = 0
			while(i < arr.size()):
				arr[i] = arr[i] ^ (encVal & 0xFFFF)
				encVal *= 1103515245
				encVal += 24691
				i += 1
		else:
			encVal = arr[arr.size() - 1]
			var i = arr.size() - 1
			while (i >= 0):
				arr[i] = arr[i] ^ (encVal & 0xFFFF);
				encVal *= 1103515245;
				encVal += 24691;
				i -= 1
		
		return arr

	func convertFromScannedFBPP(image: IndexedImage) -> void:
		print("Loading Scanned 4BPP")
		image.width = nTilesX
		image.height = nTilesY
		image.emptyPixels()
		var imageSection: PackedByteArray = myBytes.slice(48)
		
		var data: Array[int] = []
		var i: int = 0
		var wh: int = image.width * image.height
		while (i < wh/4):
			data.append(imageSection.decode_u16(i*2))
			i += 1
			
		data = decrypt(data)
		image.myParams.encKey = encVal
		
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
		print("Loading Scanned 8BPP")
		image.width = nTilesX
		image.height = nTilesY
		image.emptyPixels()
		var imageSection: PackedByteArray = myBytes.slice(48)
	
		var data: Array[int] = []
		var i: int = 0
		var wh: int = image.width * image.height
		while (i < wh/4):
			data.append(imageSection.decode_u16(i*2))
			i += 1
		
		data = decrypt(data)
		image.myParams.encKey = encVal
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
		print("Loading Tiled 4BPP")
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
		print("Loading Tiled 8BPP")
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

	func encrypt(arr: Array[int]) -> PackedByteArray:
		var output: PackedByteArray = []
		output.resize(arr.size())
		if (frontToBack):
			var i = arr.size() - 1
			while(i > 0):
				var val: int = arr[i - 1] | arr[i] << 8
				encVal = (encVal - 24691) * 4005161829
				val ^= (encVal & 0xFFFF)
				output[i] = val >> 8 & 0xFF
				output[i - 1] = val & 0xFF
				i -= 2
		else:
			var i = 1
			while (i < arr.size()):
				var val: int = arr[i - 1] | arr[i] << 8
				encVal = (encVal - 24691) * 4005161829
				val ^= (encVal & 0xFFFF)
				output[i] = val >> 8 & 0xFF
				output[i - 1] = val & 0xFF
				i += 2
		encVal = (encVal - 24691) * 4005161829
		var finalVal = encVal & 0xFFFF
		if (frontToBack):
			output[-1] = finalVal >> 8 & 0xFF
			output[-2] = finalVal & 0xFF
		else:
			output[1] = finalVal >> 8 & 0xFF
			output[0] = finalVal & 0xFF
		return output

	func convertToScannedFBPP(image: IndexedImage) -> PackedByteArray:
		print("Writing Scanned 4BPP")
		var flatPix: PackedByteArray = image.flatPixels()
		var data: Array[int] = []
		var pixInd = 0
		while(pixInd < flatPix.size()):
			var doublePix: int = flatPix[pixInd] | (flatPix[pixInd + 1] << 4)
			data.append(doublePix)
			pixInd += 2
			
		return encrypt(data)
		
	func convertToScannedEBPP(image: IndexedImage) -> PackedByteArray:
		print("Writing Scanned 8BPP")
		var data: Array[int] = image.flatPixels()
		return encrypt(data)

	func convertToTileFBPP(image: IndexedImage) -> PackedByteArray:
		print("Writing Tiled 4BPP")
		var chunkMan: ChunkManager = ChunkManager.new(1,1)
		var chunksWide = image.width/8 / chunkMan.cols
		var pitch: int = image.width/2
		var src: PackedByteArray = []
		var i = 0
		while(i < image.height):
			src.append_array(image.myPixels[i])
			i += 1
			
		var dest: PackedByteArray = []
		i = 0
		while (i < numTiles):
			var j = 0
			while (j < 8):
				var srcY: int = chunkMan.getComponentY(8, j)
				var k = 0
				while(k < 4):
					var srcX: int = chunkMan.getComponentX(4, k)
					var leftPixel = src[2 * (srcY * pitch + srcX)] & 0xF
					var rightPixel = src[2 * (srcY * pitch + srcX) + 1] & 0xF
					dest.append(((rightPixel << 4) & 0xF0) | leftPixel)
					k += 1
				j += 1
			chunkMan.advance(chunksWide)
			i += 1
		return dest

	func convertToTileEBPP(image: IndexedImage) -> PackedByteArray:
		print("Writing Tiled 8BPP")
		var chunkMan: ChunkManager = ChunkManager.new(1,1)
		var chunksWide = image.width/8 / chunkMan.cols
		var pitch: int = image.width/2
		var src: PackedByteArray = []
		var i = 0
		while(i < image.height):
			src.append_array(image.myPixels[i])
			i += 1
		
		var dest: PackedByteArray = []
		i = 0
		while (i < numTiles):
			var j = 0
			while (j < 8):
				var srcY: int = chunkMan.getComponentY(8, j)
				var k = 0
				while(k < 8):
					var srcX: int = chunkMan.getComponentX(8, k)
					var pixel = src[(srcY * pitch + srcX)] & 0xFF
					dest.append(pixel)
					k += 1
				j += 1
			chunkMan.advance(chunksWide)
			i += 1
		return dest
		
	func initTiles(width: int, height: int, bpp: int, enc: int):
		if (width % 8 != 0 || height % 8 != 0):
			print("Bad Width or Height")
			return
		tileSize = bpp * 8
		nTilesX = width/8
		nTilesY = height/8
		numTiles = nTilesX * nTilesY
		bitDepth = bpp
		encVal = enc
		
# Indexed Image
# https://github.com/turtleisaac/Nds4j/blob/main/src/main/java/io/github/turtleisaac/nds4j/images/IndexedImage.java
class IndexedImage:
	const paletteChunkHeader: PackedByteArray = [0x50,0x4C,0x54,0x45]
	const dataChunkHeader: PackedByteArray = [0x49,0x44,0x41,0x54]
	const imageChunkHeader: PackedByteArray = [0x49,0x48,0x44,0x52]
	const endChunkHeader: PackedByteArray = [0x49,0x45,0x4E,0x44]
	const PNGHeader: PackedByteArray = [0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]
	
	var myImage: Image
	var myPixels: Array[PackedByteArray]
	var width: int
	var height: int
	var myPalette: Palette
	var bpp: int
	var regions: Vector3i = Vector3i(0, 0, 1)
	
	var myParams: NCGRParams
	class NCGRParams:
		var encKey: int
		var scanned: bool
		var mappingType: int
		var vram: bool
		var frontToBack: bool
	
	func region(r: int) -> Image:
		if (r >= regions.z):
			print("Bad Region Request")
			return myImage
		var startX = 0
		var startY = 0
		var i = 1
		while (i < r):
			startX += regions.x
			if (startX >= width):
				startX = 0
				startY += regions.y
			i += 1
		return myImage.get_region(Rect2i(startX, startY, regions.x, regions.y))
	
	func emptyPixels() -> void:
		myImage = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
		myPixels = []
		var i: int = 0
		while (i < height):
			var temp = PackedByteArray([])
			temp.resize(width)
			myPixels.append(temp)
			i += 1
	
	func setPixel(x: int, y: int, p: int) -> void:
		myImage.set_pixel(x, y, myPalette.colors[p])
		myPixels[y][x] = p
		
	func render() -> void:
		var y = 0
		while(y < height):
			var x = 0
			while(x < width):
				var pixInd = myPixels[y][x]
				myImage.set_pixel(x, y, myPalette.colors[pixInd])
				x += 1
			y += 1
	
	func flatPixels() -> PackedByteArray:
		var retBytes: PackedByteArray = []
		var i = 0
		while(i < myPixels.size()):
			retBytes.append_array(myPixels[i])
			i += 1
		return retBytes
	
	func updatePalette(newPalette: Palette) -> void:
		myPalette = newPalette
		bpp = myPalette.bitDepth
		render()
	
	func populatePNG(pngBytes: PackedByteArray) -> void:
		emptyPixels()
		var numBytes: int = ceil(bpp*width/8)
		var y: int = 0
		var idx: int = 0
		while(y < height):
			var scanLine: PackedByteArray = pngBytes.slice(idx + 1, idx + 1 + numBytes)
			idx += numBytes+1
			var x: int = 0
			while (x < scanLine.size()):
				match bpp:
					2:
						var section: int = (scanLine[x] >> 4) & 0xf
						setPixel(x*2, y, (section >> 2) & 0x3)
						setPixel(x*2 + 1, y, section & 0x3)
					4:
						setPixel(x*2, y, (scanLine[x] >> 4) & 0xf)
						setPixel(x*2 + 1, y, (scanLine[x]) & 0xf)
					8:
						setPixel(x, y, scanLine[x])
				x += 1
			y += 1
	
	func scanLines() -> PackedByteArray:
		var returnBytes: PackedByteArray = []
		var i = 0
		while (i < myPixels.size()):
			var scanline: PackedByteArray = myPixels[i]
			returnBytes.append(0) # Filter Method
			var j = 0
			while(j < scanline.size()):
				match bpp:
					8:
						returnBytes.append(scanline[j])
						j -= 1
					4:
						var byte = (scanline[j] << 4) | (scanline[j + 1] & 0xF)
						returnBytes.append(byte)
					2:
						var byte = (scanline[j] << 2) | ((scanline[j + 1] & 0x3) << 4)
						returnBytes.append(byte)
				j += 2
			i += 1
		return returnBytes
	
	func fromPNG(bytes: PackedByteArray) -> void:
		var paletteIndex: int
		var dataIndex: int
		if (bytes.slice(0, 8) != PNGHeader):
			print("NOT A PNG")
			return
		
		var currInd = 0
		while (currInd < bytes.size() - 4):
			var currFour: PackedByteArray = bytes.slice(currInd, currInd + 4)
			if (currFour == paletteChunkHeader):
				paletteIndex = currInd
			if (currFour == dataChunkHeader):
				dataIndex = currInd
			if (currFour == endChunkHeader):
				break
			currInd += 1
			
		width = swapEndianInt32(bytes.decode_u32(16))
		height = swapEndianInt32(bytes.decode_u32(20))
		myPalette = Palette.new()
		
		myPalette.bitDepth = bytes.decode_u8(24)
		bpp = bytes.decode_u8(24)
		var valid: bool = true && bytes.decode_u8(25) == 3
		valid = valid && bytes.decode_u8(26) == 0
		valid = valid && bytes.decode_u8(27) == 0
		valid = valid && bytes.decode_u8(28) <= 1
		
		if (!valid):
			print("PNG IMPROPERLY FORMATTED")
			return
	
		var chunkLength: int = swapEndianInt32(bytes.decode_u32(paletteIndex - 4))
		var i = 0
		while (i < chunkLength/3):
			var nColor: Color = Color()
			var cVal: int = bytes.decode_u8(paletteIndex + 4 + i*3)
			nColor.r8 = cVal
			cVal = bytes.decode_u8(paletteIndex + 4 + i*3 + 1)
			nColor.g8 = cVal
			cVal = bytes.decode_u8(paletteIndex + 4 + i*3 + 2)
			nColor.b8 = cVal
			myPalette.colors.append(nColor)
			i += 1
	
		chunkLength = swapEndianInt32(bytes.decode_u32(dataIndex-4))
		var toDecomp: PackedByteArray = bytes.slice(dataIndex + 4, dataIndex + 4 + chunkLength)
		var decompSize: int = width*height/2 + width
		var decompBytes: PackedByteArray = toDecomp.decompress(decompSize, 1)
		populatePNG(decompBytes)
		render()
	
	func fromNCGR(bytes: PackedByteArray, pal: Palette) -> void:
		var myNCGR = NCGR.new()
		myPalette = pal
		bpp = pal.bitDepth
		myNCGR.process(bytes)
		myParams = NCGRParams.new()
		myParams.scanned = myNCGR.scanned
		myParams.mappingType = myNCGR.mappingType
		myParams.vram = myNCGR.vram
		myParams.frontToBack = myNCGR.frontToBack
		myNCGR.setImage(self)
		render()
	
	func toPNG() -> PackedByteArray:
		var imageHead: PackedByteArray = []
		imageHead.append_array(imageChunkHeader)
		print(myPalette.bitDepth)
		var bpp: int = myPalette.bitDepth
		imageHead.resize(imageHead.size() + 8)
		imageHead.encode_u32(4, swapEndianInt32(width))
		imageHead.encode_u32(8, swapEndianInt32(height))
		imageHead.append_array([bpp, 3, 0, 0, 0])
		
		var paletteBuff: PackedByteArray = []
		paletteBuff.append_array(paletteChunkHeader)
		var i = 0
		while (i < myPalette.colors.size()):
			paletteBuff.append_array([myPalette.colors[i].r8, myPalette.colors[i].g8, myPalette.colors[i].b8])
			i += 1
		
		var dataBuff: PackedByteArray = []
		dataBuff.append_array(dataChunkHeader)
		var data = scanLines()
		dataBuff.append_array(data.compress(1))
		
		var returnArray: PackedByteArray = []
		returnArray.append_array(PNGHeader)
		
		returnArray.resize(returnArray.size() + 4)
		returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(imageHead.size()-4))
		returnArray.append_array(imageHead)
		returnArray.resize(returnArray.size() + 4)
		returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(NdsGd.CRC.calculateCRC32(imageHead)))
		
		returnArray.resize(returnArray.size() + 4)
		returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(paletteBuff.size()-4))
		returnArray.append_array(paletteBuff)
		returnArray.resize(returnArray.size() + 4)
		returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(NdsGd.CRC.calculateCRC32(paletteBuff)))
		
		returnArray.resize(returnArray.size() + 4)
		returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(dataBuff.size()-4))
		returnArray.append_array(dataBuff)
		returnArray.resize(returnArray.size() + 4)
		returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(NdsGd.CRC.calculateCRC32(dataBuff)))
		
		returnArray.resize(returnArray.size() + 4)
		returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(endChunkHeader.size()-4))
		returnArray.append_array(endChunkHeader)
		returnArray.resize(returnArray.size() + 4)
		returnArray.encode_u32(returnArray.size() - 4, swapEndianInt32(NdsGd.CRC.calculateCRC32(endChunkHeader)))
		
		return returnArray
	
	func toNCGR(p: NCGRParams) -> PackedByteArray:
		var myNCGR: NCGR = NCGR.new()
		myParams = p
		myNCGR.initTiles(width, height, bpp, p.encKey)
		myNCGR.scanned = p.scanned
		myNCGR.mappingType = p.mappingType
		myNCGR.vram = p.vram
		myNCGR.frontToBack = p.frontToBack
		var pixelBuf: PackedByteArray
		if (p.scanned && bpp == 8):
			pixelBuf = myNCGR.convertToScannedEBPP(self)
		elif (p.scanned):
			pixelBuf = myNCGR.convertToScannedFBPP(self)
		elif(myPalette.bitDepth == 8):
			pixelBuf = myNCGR.convertToTileEBPP(self)
		else:
			pixelBuf = myNCGR.convertToTileFBPP(self)
		
		var retBytes = myNCGR.headerBytes()
		retBytes.encode_u32(40, pixelBuf.size())
		retBytes.append_array(pixelBuf)
		
		return retBytes
	
	static func swapEndianInt32(i: int) -> int:
		var b1 = (i & 0xFF000000) >> 24
		var b2 = (i & 0x00FF0000) >> 8
		var b3 = (i & 0x0000FF00) << 8
		var b4 = (i & 0x000000FF) << 24
		return b1 | b2 | b3 | b4
