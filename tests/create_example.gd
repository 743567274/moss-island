extends SceneTree

func _initialize() -> void:
	var state=FarmState.new(1792454400.0)
	state.data.id="moss-island-example-v2"
	var f=FileAccess.open("res://data/example_save.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"payload":state.data,"sha256":LocalSaveProvider.digest(state.data)},"\t",false,true))
	f.close()
	quit()
