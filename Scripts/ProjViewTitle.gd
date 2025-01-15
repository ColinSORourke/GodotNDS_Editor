extends CenterContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$ProjectTitle.text = ProjManager.ProjName
	$GameTitle.text = ProjManager.ProjHeader.gameTitle
