extends LineEdit


func _on_text_changed(new_text: String) -> void:
	var temp = self.caret_column
	var actualNewText: String = "0x"
	var i = 2
	new_text = new_text.to_upper()
	while (i < 10 && i < new_text.length()):
		if(new_text[i] in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]):
			actualNewText += new_text[i]
		i += 1
	self.text = actualNewText
	self.caret_column = temp
