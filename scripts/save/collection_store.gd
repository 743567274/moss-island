class_name CollectionStore
extends RefCounted

var path: String
func _init(storage_path: String) -> void:
	path=storage_path

func load_collection(farm_id: String, exact_path: String="") -> Dictionary:
	for candidate in ([path,path+".bak"] if exact_path.is_empty() else [exact_path]):
		if not FileAccess.file_exists(candidate):
			continue
		var json=JSON.new()
		if json.parse(FileAccess.get_file_as_string(candidate))!=OK or not json.data is Dictionary:
			continue
		var envelope=json.data
		if envelope.has_all(["payload","sha256"]) and envelope.payload is Dictionary and LocalSaveProvider.digest(envelope.payload)==envelope.sha256 and envelope.payload.get("crop_revision",0)==2 and envelope.payload.get("farm_id","")==farm_id and valid_collection(envelope.payload.get("collection")):
			return crop_only(envelope.payload.get("collection",{}))
	return {}

func save_collection(farm_id: String, collection: Dictionary) -> Error:
	var payload={"version":1,"crop_revision":2,"farm_id":farm_id,"collection":collection}
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"payload":payload,"sha256":LocalSaveProvider.digest(payload)},"\t",false,true))
	file.flush()
	var err=file.get_error()
	file.close()
	if err!=OK:
		return err
	if load_collection(farm_id,path+".tmp").is_empty():
		return ERR_FILE_CORRUPT
	if not load_collection(farm_id,path).is_empty():
		err=DirAccess.copy_absolute(path,path+".bak")
		if err!=OK:
			return err
	return DirAccess.rename_absolute(path+".tmp",path)

static func valid_collection(value: Variant) -> bool:
	if not value is Dictionary or not value.get("crops") is Dictionary or not value.get("discovered") is Array:
		return false
	for key in value.crops:
		var record=value.crops[key]
		if not record is Dictionary or not (record.get("count") is float or record.get("count") is int) or not is_finite(float(record.count)) or record.count<0:
			return false
	return true

static func merge(current: Dictionary, archived: Dictionary) -> Dictionary:
	var result=crop_only(current)
	for kind in archived.get("crops",{}):
		if not ContentCatalog.crops.has(kind):
			continue
		var entry=archived.crops[kind]
		if entry is Dictionary and entry.get("count",0)>result.crops.get(kind,{}).get("count",0):
			result.crops[kind]=entry.duplicate(true)
	for id in archived.get("discovered",[]):
		if id is String and ContentCatalog.crops.has(id) and not id in result.discovered:
			result.discovered.append(id)
	return result

static func crop_only(value: Dictionary) -> Dictionary:
	ContentCatalog.load_catalog()
	var found=[]
	for id in value.get("discovered",[]):
		if id is String and ContentCatalog.crops.has(id):
			found.append(id)
	var known={}
	for id in value.get("crops",{}):
		if ContentCatalog.crops.has(id):
			known[id]=value.crops[id].duplicate(true)
	return {"crops":known,"discovered":found}
