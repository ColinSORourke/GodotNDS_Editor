extends Node

# Algorithm taken from NDS4J/CodeCompression
static func Decompress(file: String) -> void:
	var reader: FileAccess = FileAccess.open(file, FileAccess.READ)
	
	var target: FileAccess = FileAccess.open(file.get_basename() + "decomp." + file.get_extension(), 7)
	
	var appendedDataAmt: int = detectAppendedData(reader)
	
	if (appendedDataAmt == -1):
		return
	
	var dataSize: int = reader.get_length()
	reader.seek(0)
	var appendedData: PackedByteArray
	if (appendedDataAmt == 0):
		appendedData = PackedByteArray()
	else:
		appendedData = reader.get_buffer(dataSize - appendedDataAmt)
		reader.seek(dataSize - appendedDataAmt)
		dataSize -= appendedDataAmt
	
	reader.seek(dataSize - 4)
	if (reader.get_32() == 0):
		return
	
	reader.seek(reader.get_length() - 8)
	var composite: int = reader.get_32()
	var headerLength: int = composite >> 24
	var compressedLength: int = composite & 0xFFFFFF
	var extraSize: int = reader.get_32()
	
	if (dataSize < headerLength):
		print("File is too small for Header size")
		return
	if (compressedLength > dataSize):
		print("Compressed Length doesn't fit in the input file")
	
	reader.seek(dataSize - headerLength)
	while (reader.get_position() < reader.get_length() -8):
		var byte: int = reader.get_32()
		if (byte & 0xFF != 0xFF):
			print("Header padding isn't entirely 0xFF")
			return
	
	if (compressedLength >= dataSize):
		compressedLength = dataSize
		
	var passThruLength: int = dataSize - compressedLength
	reader.seek(0)
	var passThruData: PackedByteArray = reader.get_buffer(passThruLength)
	target.seek(0)
	target.store_buffer(passThruData)
	
	var compressedData: PackedByteArray = reader.get_buffer(compressedLength - headerLength)
	var decompressedData: PackedByteArray = PackedByteArray()
	decompressedData.resize(dataSize + extraSize - passThruLength)
	
	var currentOutSize: int = 0
	var decompressedLength: int  = dataSize + extraSize - passThruLength
	var flags: int = 0
	var readBytes: int = 0
	var mask: int = 1
	
	while (currentOutSize < decompressedLength):
		if (mask == 1):
			if (readBytes >= compressedLength):
				print("Not enough data to read")
				return
			flags = compressedData[compressedData.size() - 1 - readBytes] & 0xff;
			readBytes += 1
			mask = 0x80
		else:
			mask >>= 1
		
		if (flags & mask != 0):
			if (readBytes + 1 >= dataSize):
				print("Not enough data to decompress")
				return
			
			
			var byte1: int = compressedData[compressedData.size() - 1 - readBytes] & 0xFF
			readBytes += 1
			var byte2: int = compressedData[compressedData.size() - 1 - readBytes] & 0xFF
			readBytes += 1
			
			var length: int = (((byte1 & 0xFF) >> 4) + 3) & 0xFF
			var disp: int = (((byte1 & 0x0F) << 8) | byte2) + 3;
			
			if (disp > currentOutSize):
				if (currentOutSize < 2):
					print("Can't go back more")
					return
				disp = 2
				
			var bufIdx: int = currentOutSize - disp
			var i = 0
			while (i < length):
				
				var next: int = decompressedData[decompressedData.size() - 1 - bufIdx]
				bufIdx += 1
				decompressedData[decompressedData.size() - 1 - currentOutSize] = next
				currentOutSize += 1
				i += 1
		else:
			if (readBytes > dataSize):
				print("Not enough data to decompress")
				return
			var next: int = compressedData[compressedData.size() - 1 - readBytes]
			readBytes += 1
			decompressedData[decompressedData.size() - 1 - currentOutSize] = next
			currentOutSize += 1
			
	
	target.store_buffer(decompressedData)
	target.store_buffer(appendedData)
	
# Algorithm taken from NDSPY/CodeCompression
static func Compress(fileFrom: String, fileTo: String, arm9: bool = false) -> void:
	var target = FileAccess.open(fileTo, FileAccess.WRITE)
	var buffer = FileAccess.get_file_as_bytes(fileFrom)
	
	var prefix
	if (arm9):
		prefix = buffer.slice(0, 0x4000)
		buffer = buffer.slice(0x4000)
		
	var data = buffer.duplicate()
	buffer.reverse()
	
	var myLZ = LZCompress.new(buffer)
	
	#var start = Time.get_unix_time_from_system() * 1000
	#print("Started Compression at: " + str(start) + " unix Time")
	var compResults = myLZ.compress(3, 0x1002, 18, true)
	#var end = Time.get_unix_time_from_system() * 1000
	#print("Ended Compression at: " + str(end) + " unix time")
	#print("Compression took " + str((end - start)/1000.0) + " seconds") 
	var compressedBuff = compResults[0]
	var ignorableD = compResults[1]
	var ignorableC = compResults[2]
	compressedBuff.reverse()
	if (not compressedBuff or (buffer.size() - 4 < ( (compressedBuff.size() + 3) & ~4)  + 8) ):
		print("Compressed size too large")
		compressedBuff = buffer
		while (compressedBuff.size() % 4 == 0):
			compressedBuff.append(0x00)
		target.store_buffer(compressedBuff)
		target.close()
	else:
		var actualCompLen = compressedBuff.size() - ignorableC
		var headerLen = 8
		compressedBuff = data.slice(0, ignorableD) + compressedBuff.slice(ignorableC)
		var extraLen = buffer.size() - compressedBuff.size()
		while (compressedBuff.size() % 4 != 0):
			compressedBuff.append(0xFF)
			headerLen += 1
		
		var ptr = compressedBuff.size()
		var fillerArray = PackedByteArray()
		fillerArray.resize(8)
		fillerArray.fill(0x00)
		compressedBuff.append_array(fillerArray)
		compressedBuff.encode_u32(ptr, actualCompLen + headerLen)
		compressedBuff[ptr + 3] = headerLen
		compressedBuff.encode_u32(ptr + 4, extraLen - headerLen)
		
		target.store_buffer(prefix)
		target.store_buffer(compressedBuff)
		target.close()

# Utility Class, Algorithms taken from NDSPY/CodeCompression
class LZCompress:
	var data: PackedByteArray
	var dataString: String
	var dataSize: int
	var maxMatchDiff: int
	var maxMatchLen: int
	
	var searchReverse: bool = false
	var zerosAtEnd: bool = false
	var posSubtract: int

	func _init(myData: PackedByteArray):
		data = myData
		dataString = unicodeStr(myData)
		dataSize = data.size()
	
	static func unicodeStr(pb: PackedByteArray):
		var retStr: String = ""
		retStr = retStr.rpad(pb.size(), "f")
		var i = 0
		while (i < pb.size()):
			retStr[i] = String.chr(pb[i] + 256)
			i += 1
		return retStr
	
	# MODIFIED from NDSPY/CodeCompression to achieve compression that better matches Nintendo's original files
	# Modification has to do with rolling back ignore positions after completing compression, to use more of original data when it is space equivalent.
		# Very occasionally will produce larger files than NDSPY, but in a way that exactly matches the files Nintendo produced in the original ROM
	func compress(pSubtract: int, maxMDiff: int, maxMLen: int, sRev: bool):
		posSubtract = pSubtract
		maxMatchDiff = maxMDiff
		maxMatchLen = maxMLen
		searchReverse = sRev
		
		var result: PackedByteArray = PackedByteArray()
		var currentInd: int = 0
		var ignoreDict: Dictionary = {}
		var bestSavingsSoFar: int = 0
		
		while (currentInd < dataSize):
			var blockFlags = 0
			var blockFlagsOffset = result.size()
			result.append(0x00)
			
			var i = 0
			while (i < 8 && currentInd < dataSize):
				var searchVars = self.compressionSearch(currentInd)
				
				var searchDisp = currentInd - searchVars[0] - posSubtract
				if (searchVars[1] > 2):
					blockFlags |= (1 << (7 - i))
					result.append((((searchVars[1] - 3) & 0x0F) << 4) | ((searchDisp >> 8) & 0x0F))
					result.append(searchDisp & 0xFF)
					currentInd += searchVars[1]
				else:
					result.append(data[currentInd])
					currentInd += 1
				
				var savingsNow = currentInd - result.size()
				if (savingsNow > bestSavingsSoFar):
					bestSavingsSoFar = savingsNow
					if (savingsNow not in ignoreDict):
						ignoreDict[savingsNow] = Vector2i(currentInd, result.size())
				
				i += 1
			
			result.encode_u8(blockFlagsOffset, blockFlags)
			
		var finalSavings:int = currentInd - result.size()
		if (finalSavings < bestSavingsSoFar):
			finalSavings += 1
			while (finalSavings not in ignoreDict):
				print("Rounding up")
				finalSavings += 1
			print(finalSavings)
			return [result, currentInd - ignoreDict[finalSavings][0], len(result) - ignoreDict[finalSavings][1]]
		else:
			return [result, 0, 0]
		
	func compressionSearch(pos: int, searchCount: int = 0) -> Vector2i:
		var start: int = max(0, pos - maxMatchDiff)
		var lower: int = 0
		var upper: int = min(maxMatchLen, dataSize - pos)
		
		var startTime: float = 0
		
		var recordMatchPos = 0
		var recordMatchLen = 0
		var mySubData = dataString.substr(start, (pos - start))
		var matchLen: int
		var myMatch: String
		var matchPos: int
		while (lower <= upper):
			matchLen = (lower + upper) / 2
			myMatch = dataString.substr(pos, (lower + upper) / 2)
			
			if (searchReverse):
				matchPos = mySubData.rfind(myMatch)
			else:
				matchPos = mySubData.find(myMatch)
			if (matchPos == -1):
				upper = matchLen - 1
			else:
				matchPos = start + matchPos
				if matchLen > recordMatchLen:
					recordMatchPos = matchPos
					recordMatchLen = matchLen
				lower = matchLen + 1
			
		return Vector2i(recordMatchPos, recordMatchLen)

# Utility Function, algorithm taken from NDS4J/Code Compression
static func detectAppendedData(file: FileAccess) -> int:
	var possibleAmt: int = 0
	while (possibleAmt < 0x20):
		if (file.get_length() - possibleAmt - 5 > 0):
			var headerLength: int = file.get_length() - possibleAmt - 5
			file.seek(file.get_length() - possibleAmt - 8)
			var composite: int = file.get_32()
			headerLength = composite >> 24
			var compressedLength: int = composite & 0xFFFFFF
			var extraSize: int = file.get_32()
			
			if (headerLength < 8 or compressedLength > file.get_length()):
				possibleAmt += 4
				# end here
			else: 
				file.seek(file.get_length() - possibleAmt - headerLength)
				var invalidFound: bool = false
				while (!invalidFound && file.get_position() < file.get_length() - possibleAmt - 8):
					var byte: int = file.get_32()
					if (byte & 0xFF != 0xFF):
						invalidFound = true
						file.seek(file.get_length() - 1)
				if (invalidFound):
					possibleAmt += 4
				else: 
					return possibleAmt
		else:
			return -1
	return -1
