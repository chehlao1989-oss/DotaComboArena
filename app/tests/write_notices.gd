extends SceneTree

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--notices-output="):
			var f = FileAccess.open(arg.trim_prefix("--notices-output="), FileAccess.WRITE)
			if f == null:
				quit(1)
				return
			f.store_string("GODOT ENGINE\n\n" + Engine.get_license_text())
			f.store_string("\n\nTHIRD PARTY COPYRIGHTS\n\n" + JSON.stringify(Engine.get_copyright_info(), "\t"))
			var licenses = Engine.get_license_info()
			for name in licenses:
				f.store_string("\n\n" + name + "\n\n" + str(licenses[name]))
			f.close()
			quit(0)
			return
	quit(1)
