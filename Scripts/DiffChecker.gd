extends VBoxContainer


var romA = ""

var romB = ""

var selectingA: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$RomLabel.text = romA
	$RomLabel2.text = romB
	pass # Replace with function body.


func onRomSelected(selected: String) -> void:
	if (selected.get_extension() != "nds"):
		print(selected)
		selected = "Invalid File!"
	if (selectingA):
		romA = selected
		$RomLabel.text = romA
	else:
		romB = selected
		$RomLabel2.text = romB
	
func openRomADialog() -> void:
	$RomDialog.visible =  true
	selectingA = true
	pass # Replace with function body.
	
func openRomBDialog() -> void:
	$RomDialog.visible =  true
	selectingA = false
	pass # Replace with function body.

func checkHeaderDiffs() -> void:
	var romFileA = FileAccess.open(romA, FileAccess.READ)
	var headerA = NdsGd.NitroHeader.readHeader(romFileA)
	var romFileB = FileAccess.open(romB, FileAccess.READ)
	var headerB = NdsGd.NitroHeader.readHeader(romFileB)
	NdsGd.NitroHeader.compareHeader(headerA, headerB)
	pass

	

	
	
