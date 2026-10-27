class_name LocalSaveProvider
extends SaveProvider

var path: String
var notice = ""

func _init(save_path: String = "user://farm.json") -> void:
	path = save_path

static func canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var sorted = {}
		var keys = value.keys()
		keys.sort()
		for key in keys:
			sorted[key] = canonical(value[key])
		return sorted
	if value is Array:
		var result = []
		for item in value:
			result.append(canonical(item))
		return result
	return value

static func digest(payload: Dictionary) -> String:
	# Normalize numbers through JSON before hashing; parsed numbers become floats.
	var normalized = JSON.parse_string(JSON.stringify(payload))
	return JSON.stringify(canonical(normalized), "", false, true).sha256_text()

func decode(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 2 * 1024 * 1024:
		return null
	var parser=JSON.new()
	if parser.parse(file.get_as_text())!=OK:
		return null
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.has_all(["payload", "sha256"]) or not envelope.payload is Dictionary:
		return null
	if digest(envelope.payload) != envelope.sha256:
		return null
	return envelope.payload

func read_save() -> Variant:
	for candidate in [path, path + ".bak",path+".bak2",path+".bak3"]:
		var payload = decode(candidate)
		if payload != null:
			payload = SaveManager.migrate_save(payload)
			if FarmState.valid(payload):
				if candidate!=path:
					notice = "主存档异常，已恢复备份"
				return payload
	if FileAccess.file_exists(path):
		notice = "存档与备份不可用，已创建新农场；原文件保留为 .damaged"
		DirAccess.copy_absolute(path, path + ".damaged")
	return null

func write_save(state: Dictionary) -> Error:
	if not FarmState.valid(state):
		return ERR_INVALID_DATA
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"payload": state, "sha256": digest(state)}, "\t", false, true))
	file.flush()
	var err = file.get_error()
	file.close()
	if err != OK or decode(path + ".tmp") == null:
		return ERR_FILE_CORRUPT
	# Only back up validated saves; never overwrite the good backup with a corrupt primary.
	var old = decode(path)
	if old != null and FarmState.valid(SaveManager.migrate_save(old)):
		for pair in [[".bak2",".bak3"],[".bak",".bak2"]]:
			var backup=decode(path+pair[0])
			if backup!=null and FarmState.valid(SaveManager.migrate_save(backup)):
				err=DirAccess.copy_absolute(path+pair[0],path+pair[1])
				if err!=OK:
					return err
		err = DirAccess.copy_absolute(path, path + ".bak")
		if err != OK:
			return err
	return DirAccess.rename_absolute(path + ".tmp", path)
