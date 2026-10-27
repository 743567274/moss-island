class_name SaveProvider
extends RefCounted

func read_save() -> Variant:
	return null

func write_save(_state: Dictionary) -> Error:
	return ERR_UNAVAILABLE
