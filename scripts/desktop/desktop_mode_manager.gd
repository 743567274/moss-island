class_name DesktopModeManager
extends Node

signal changed
signal problem(message: String)
signal power_changed(active: bool)
signal visibility_changed(covered: bool)
signal bridge_failed
signal pointer_moved(position: Vector2)
var desktop = false
var locked = false
var bridge_pid = -1
var ipc = ""
var last_status = ""
var prefs: SettingsManager
var pending_enter = false
var ready_bridge = false
var last_power=""
var last_visibility=""
var requested_action="enter"
var controller_pid=0
var input_offset=0
var input_pending=""
var pointer_position=Vector2.ZERO
var pointer_known=false
var pointer_buttons=0
var pointer_inside=false

func _process(_delta: float) -> void:
	if ipc.is_empty():
		return
	if locked:
		return
	var path=ipc.path_join("input-events")
	if not FileAccess.file_exists(path):
		return
	var stream=FileAccess.open(path,FileAccess.READ)
	if stream==null:
		return
	if stream.get_length()<input_offset:
		input_offset=0
		input_pending=""
	stream.seek(input_offset)
	input_pending+=stream.get_buffer(mini(65536,stream.get_length()-input_offset)).get_string_from_utf8()
	input_offset=stream.get_position()
	stream.close()
	if not input_pending.is_empty():
		# Align lock/UI state before the first click, without waiting for the status timer.
		_poll()
	while input_pending.contains("\n"):
		var end=input_pending.find("\n")
		var line=input_pending.left(end)
		input_pending=input_pending.substr(end+1)
		_deliver_pointer(line)

func _deliver_pointer(line: String) -> void:
	var parts=line.split("|")
	if parts.size()!=5:
		return
	var message=int(parts[0])
	if message==0:
		_release_pointer()
		return
	if not desktop or locked:
		return
	# Queue coordinates are normalized; deliver directly in viewport coordinates.
	var point=Vector2(float(parts[1]),float(parts[2]))*get_viewport().get_visible_rect().size
	var raw_buttons=int(parts[3])
	var buttons=(MOUSE_BUTTON_MASK_LEFT if raw_buttons&1 else 0)|(MOUSE_BUTTON_MASK_MIDDLE if raw_buttons&16 else 0)
	var motion=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	motion.relative=point-pointer_position if pointer_known else Vector2.ZERO
	motion.button_mask=buttons
	pointer_position=point
	pointer_known=true
	pointer_buttons=buttons
	# WorkerW never receives a native mouse-enter notification. Without this,
	# unhandled 3D clicks work while Control buttons silently reject the same input.
	if not pointer_inside:
		get_viewport().notify_mouse_entered()
		pointer_inside=true
	get_viewport().push_input(motion,true)
	# Godot 4.6 native-window hover lookup depends on the OS hit window,
	# which is Explorer for wallpaper. Synchronize the UI hover after motion.
	pointer_moved.emit(point)
	if message==512:
		return
	var event=InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_mask=buttons
	event.button_index=MOUSE_BUTTON_LEFT if message in [513,514] else MOUSE_BUTTON_MIDDLE
	event.pressed=message in [513,519,522]
	if message==522:
		event.button_index=MOUSE_BUTTON_WHEEL_UP if int(parts[4])>0 else MOUSE_BUTTON_WHEEL_DOWN
		event.factor=absf(float(parts[4]))/120.0
	get_viewport().push_input(event,true)
	if message==522:
		event=event.duplicate()
		event.pressed=false
		get_viewport().push_input(event,true)

func _release_pointer() -> void:
	pointer_moved.emit(Vector2(-100,-100))
	if pointer_inside:
		get_viewport().notify_mouse_exited()
		pointer_inside=false
	for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
		if pointer_buttons & (1<<(button-1)):
			var event=InputEventMouseButton.new()
			event.position=pointer_position
			event.global_position=pointer_position
			event.button_index=button
			event.pressed=false
			get_viewport().push_input(event,true)
	pointer_buttons=0
	pointer_known=false

func initialize(settings: SettingsManager) -> void:
	prefs = settings
	get_window().mouse_entered.connect(func(): pointer_inside=true)
	get_window().mouse_exited.connect(func(): pointer_inside=false)
	ipc = ProjectSettings.globalize_path("user://desktop-%s" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ipc)
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()
	if OS.get_name()=="Windows" and DisplayServer.get_name()!="headless" and FileAccess.file_exists(bridge_path()):
		_launch.call_deferred()

func bridge_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://native/DesktopBridge.exe")
	return OS.get_executable_path().get_base_dir().path_join("DesktopBridge.exe")

func enter(action: String="enter") -> void:
	requested_action=action
	if OS.get_name() != "Windows" or not FileAccess.file_exists(bridge_path()):
		problem.emit("Windows 桌面组件未找到，请先运行 native/build.ps1。")
		return
	pending_enter = true
	if bridge_pid > 0 and OS.is_process_running(bridge_pid) and ready_bridge:
		command(requested_action)
		pending_enter = false
		return
	if bridge_pid>0 and OS.is_process_running(bridge_pid):
		return
	_launch()

func _launch() -> void:
	if bridge_pid>0 and OS.is_process_running(bridge_pid):
		return
	ready_bridge = false
	last_status = ""
	input_offset=0
	input_pending=""
	DirAccess.remove_absolute(ipc.path_join("status"))
	DirAccess.remove_absolute(ipc.path_join("command"))
	DirAccess.remove_absolute(ipc.path_join("power"))
	bridge_pid = OS.create_process(bridge_path(), [str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)), ipc, str(OS.get_process_id()),str(controller_pid)], false)
	if bridge_pid < 0:
		pending_enter = false
		problem.emit("桌面组件启动失败。")

func command(action: String) -> void:
	var file = FileAccess.open(ipc.path_join("command.tmp"), FileAccess.WRITE)
	if file == null:
		problem.emit("无法向桌面组件发送指令。")
		return
	file.store_string("%s|%s|%s" % [Time.get_ticks_usec(), action, prefs.data.monitor])
	file.close()
	DirAccess.rename_absolute(ipc.path_join("command.tmp"), ipc.path_join("command"))

func toggle_lock() -> void:
	if desktop:
		command("unlock" if locked else "lock")

func leave() -> void:
	command("browse")

func _poll() -> void:
	if bridge_pid <= 0:
		return
	if not OS.is_process_running(bridge_pid):
		bridge_pid = -1
		ready_bridge = false
		pending_enter = false
		if desktop:
			desktop = false
			locked = false
			problem.emit("桌面组件已退出，已恢复浏览状态。")
			changed.emit()
		bridge_failed.emit()
		return
	var visibility_path=ipc.path_join("visibility")
	if FileAccess.file_exists(visibility_path):
		var value_visibility=FileAccess.get_file_as_string(visibility_path).strip_edges()
		if value_visibility!=last_visibility:
			last_visibility=value_visibility
			visibility_changed.emit(value_visibility=="covered")
	var power_path=ipc.path_join("power")
	if FileAccess.file_exists(power_path):
		var power=FileAccess.get_file_as_string(power_path).strip_edges()
		if power!=last_power:
			last_power=power
			power_changed.emit(power!="off")
	var path = ipc.path_join("status")
	if not FileAccess.file_exists(path):
		return
	var value = FileAccess.get_file_as_string(path).strip_edges().trim_prefix("\ufeff")
	if value == last_status:
		return
	last_status = value
	var parts = value.split("|")
	if parts.size() < 2:
		return
	var status = parts[1]
	if status == "ready":
		ready_bridge = true
		if pending_enter:
			command(requested_action)
			pending_enter = false
		return
	if status.begins_with("error:"):
		desktop = false
		locked = false
		problem.emit("桌面模式未能启用：" + status.trim_prefix("error:"))
	else:
		desktop = status in ["locked", "unlocked"]
		locked = status == "locked"
	changed.emit()

func _exit_tree() -> void:
	if bridge_pid > 0 and OS.is_process_running(bridge_pid):
		command("quit")
