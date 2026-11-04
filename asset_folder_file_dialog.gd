extends FileDialog

func _on_file_selected(fname: String) -> void:
	var file = FileAccess.open(fname, FileAccess.READ)
	if not is_instance_valid(file):
		self._return_to_splash_screen("Could not open file")
		return
	
	if fname.get_extension() != "bgsid":
		self._return_to_splash_screen("Not a valid .bgsid file")
		return
		
	Helper.asset_dir = fname.get_base_dir()
	Helper.bgsid = fname.get_file()
	Helper.load_assets()
	Helper.splash_screen.start_connecting()

func _on_close_requested() -> void:
	self._return_to_splash_screen("Asset folder selection cancelled")
	
func _return_to_splash_screen(err_msg: String) -> void:
	self.hide()
	Helper.splash_screen.return_to_scene(err_msg)

func _on_canceled() -> void:
	self._return_to_splash_screen("Asset folder selection cancelled")
