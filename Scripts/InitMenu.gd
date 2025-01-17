extends VBoxContainer

func close() -> void:
	self.visible = false

func open() -> void:
	self.visible = true

func openDirDialog() -> void:
	$DirDialog.visible = true

func onDirSelected(selected: String) -> void:
	var lookingFor = selected.path_join("unpacked")
	if (DirAccess.dir_exists_absolute(lookingFor)):
		if (DirAccess.dir_exists_absolute(lookingFor.path_join("data")) and FileAccess.file_exists(lookingFor.path_join("header.bin"))):
			NdsGd.openUnpacked(lookingFor)
			ProjManager.ProjName = selected.get_slice("/", selected.get_slice_count("/") - 1)
			ProjManager.ProjPath = selected
			ProjManager.iscompArm9()
			ProjManager.overlaysCompressed()
			get_tree().change_scene_to_file("res://Scenes/ProjectView.tscn")
		else:
			$AcceptDialog.dialog_text = "The 'unpacked' Folder does not contain an unpacked ROM"
			$AcceptDialog.visible = true
	else:
		$AcceptDialog.dialog_text = "That Folder doesn't contain an 'unpacked' directory"
		$AcceptDialog.visible = true
