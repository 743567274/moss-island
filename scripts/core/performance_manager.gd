class_name PerformanceManager
extends Node

var prefs: SettingsManager
var sun: DirectionalLight3D
var locked = false
var minimized = false
var unfocused = false
var display_off = false
var occluded = false
var degradation = 0
var slow_seconds = 0.0
var stable_seconds = 0.0
var render_ms = 0.0
var sampled_frames = 0
var sample_start = 0.0
var measured_fps = 0.0
var applied_shadow_size = -1
var editor_active=false

func initialize(settings: SettingsManager, light: DirectionalLight3D) -> void:
	prefs = settings
	sun = light
	sample_start = Time.get_ticks_msec() / 1000.0
	apply()

func apply() -> void:
	var cap = mini(30,int(prefs.data.fps)) if int(prefs.data.fps)>0 else 30
	if locked:
		cap = 15 if cap == 0 else mini(cap, 10)
	if prefs.data.background_saving and unfocused:
		cap = 10 if cap == 0 else mini(cap, 10)
	if prefs.data.background_saving and (minimized or display_off or occluded) and not editor_active:
		cap = 2
		RenderingServer.render_loop_enabled = false
	else:
		RenderingServer.render_loop_enabled = true
	if editor_active:
		cap=30
	Engine.max_fps = cap
	if DisplayServer.get_name()!="headless":
		var vsync=DisplayServer.VSYNC_DISABLED if int(prefs.data.fps)==0 else DisplayServer.VSYNC_ENABLED
		if DisplayServer.window_get_vsync_mode()!=vsync:
			DisplayServer.window_set_vsync_mode(vsync)
	var scale=maxf(0.5, float(prefs.data.scale) - maxf(0, degradation - 1) * 0.15)
	if not is_equal_approx(get_viewport().scaling_3d_scale,scale):
		get_viewport().scaling_3d_scale=scale
	var flat_art=sun.get_meta("flat_art",false)
	var msaa=Viewport.MSAA_2X if not flat_art and int(prefs.data.shadow)>=2 and degradation<2 else Viewport.MSAA_DISABLED
	var screen_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	if get_viewport().screen_space_aa!=screen_aa:
		get_viewport().screen_space_aa=screen_aa
	if get_viewport().msaa_3d!=msaa:
		get_viewport().msaa_3d=msaa
	sun.shadow_enabled = int(prefs.data.shadow) > 0 and degradation < 2 and not sun.get_meta("flat_art",false)
	var shadow_size = 0 if flat_art else [512, 1024, 1536][int(prefs.data.shadow)]
	if applied_shadow_size!=shadow_size:
		RenderingServer.directional_shadow_atlas_set_size(shadow_size, true)
		applied_shadow_size=shadow_size
	if not prefs.data.dynamic:
		degradation = 0

func _process(delta: float) -> void:
	if prefs == null:
		return
	sampled_frames += 1
	var now = Time.get_ticks_msec() / 1000.0
	if now - sample_start >= 2.0:
		measured_fps = sampled_frames / (now - sample_start)
		sample_start = now
		sampled_frames = 0
	render_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if not prefs.data.dynamic or locked or unfocused or minimized or occluded:
		return
	var target = float(prefs.data.fps) if prefs.data.fps > 0 else 60.0
	# CPU work and sustained delivered FPS; no claim of directly reading GPU usage.
	var render_setup_ms = RenderingServer.get_frame_setup_time_cpu()
	var expensive = maxf(render_ms, render_setup_ms)
	if expensive > 1000.0 / target * 0.9 or (measured_fps>0 and measured_fps<target*.78):
		slow_seconds += delta
		stable_seconds = 0.0
	else:
		stable_seconds += delta
		slow_seconds = maxf(0.0, slow_seconds - delta)
	if slow_seconds > 8.0 and degradation < 3:
		degradation += 1
		slow_seconds = 0.0
		apply()
	if stable_seconds > 40.0 and degradation > 0:
		degradation -= 1
		stable_seconds = 0.0
		apply()

func _notification(what: int) -> void:
	if prefs == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		unfocused = true
		apply()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		unfocused = false
		minimized = false
		apply()
	elif what == NOTIFICATION_WM_SIZE_CHANGED:
		minimized = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
		apply()
