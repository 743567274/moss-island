class_name SaveManager
extends RefCounted

var provider: SaveProvider
var state: FarmState
var last_error: Error = OK
var collection_store: CollectionStore

func _init(storage: SaveProvider = null) -> void:
	provider = storage if storage != null else LocalSaveProvider.new()
	if provider is LocalSaveProvider:
		collection_store=CollectionStore.new(provider.path.get_basename()+"-collection.json")

func load_save(initial_plot_count: int=FarmState.PLOT_COUNT) -> FarmState:
	state = FarmState.new(0,initial_plot_count)
	var loaded = provider.read_save()
	if loaded != null:
		state.data = loaded
	if collection_store!=null:
		state.data.collection=CollectionStore.merge(state.data.collection,collection_store.load_collection(state.data.id))
	state.settle(Time.get_unix_time_from_system())
	return state

func save_game_state() -> Error:
	state.settle(Time.get_unix_time_from_system())
	state.data.updated_at = Time.get_unix_time_from_system()
	last_error = provider.write_save(state.data)
	if last_error==OK and collection_store!=null:
		# Core snapshot also carries collection, so an interrupted second write cannot lose a harvest.
		collection_store.save_collection(state.data.id,state.data.collection)
	return last_error

static func migrate_save(payload: Dictionary) -> Dictionary:
	var d = payload.duplicate(true)
	# v1 used the same growth model, before decorations were introduced.
	if int(d.get("version", 0)) == 1:
		d["decorations"] = []
		d.version = 2
	if int(d.get("version",0))==2:
		d.version=3
		d.rate=1.0 if not d.get("rate",1) in [1.0,2.0,5.0] else float(d.rate)
		d["offline_cap_days"]=30
		d["collection"]={"crops":{},"products":{},"discovered":[]}
		for p in d.get("plots",[]):
			p["age"]=float(p.get("growth",0))
			p["stress"]=0.0
			p["health"]="healthy"
	if int(d.get("version",0))==3:
		d.version=4
		d.erase("creatures")
		if d.get("collection") is Dictionary:
			d.collection.erase("products")
			var discovered=[]
			ContentCatalog.load_catalog()
			for id in d.collection.get("discovered",[]):
				if id is String and ContentCatalog.crops.has(id):
					discovered.append(id)
			d.collection.discovered=discovered
	if int(d.get("version",0))==4:
		d.version=5
	if int(d.get("version",0))==5 and d.get("plots") is Array and d.plots.size()==12:
		# The user explicitly requested a one-time reset of all old species and stock.
		d.version=6
		d.plots=[]
		for i in FarmState.PLOT_COUNT:
			d.plots.append(FarmState.empty_plot(i))
		d.erase("orchard")
		d["collection"]={"crops":{},"discovered":[]}
		d.harvested=0
		d.rate=1.0
		d.paused=false
		d.offline_cap_days=0
		d.last_tick=Time.get_unix_time_from_system()
	return d

func get_save_metadata() -> Dictionary:
	return {"id": state.data.id, "version": state.data.version, "updated_at": state.data.updated_at}
