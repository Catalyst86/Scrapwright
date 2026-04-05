extends Control

## Plays the intro as a frame-by-frame slideshow, then transitions to main menu.
## Press any key or click to skip.

const FRAME_DIR := "res://assets/video/frames/"
const FRAME_COUNT := 552
const FRAME_DURATION := 0.1  # 10fps playback to match extraction rate
const LOGO_PATH := "res://assets/Northern Oak Games company logo.png"
const LOGO_DISPLAY_TIME := 3.0  # How long the logo stays on screen
const LOGO_FADE_TIME := 0.6

var _display: TextureRect
var _logo_display: TextureRect
var _bg: ColorRect
var _skippable := false
var _current_frame := 0
var _total_frames := 0
var _timer: Timer
var _showing_logo := true

func _ready() -> void:
	# Black background
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Frame display (hidden during logo)
	_display = TextureRect.new()
	_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.visible = false
	add_child(_display)

	# Show Northern Oak Games logo first
	if ResourceLoader.exists(LOGO_PATH):
		_logo_display = TextureRect.new()
		_logo_display.texture = load(LOGO_PATH)
		_logo_display.set_anchors_preset(Control.PRESET_FULL_RECT)
		_logo_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo_display.modulate.a = 0.0
		add_child(_logo_display)

		# Fade in logo
		var fade_in = create_tween()
		fade_in.tween_property(_logo_display, "modulate:a", 1.0, LOGO_FADE_TIME)
		fade_in.tween_interval(LOGO_DISPLAY_TIME)
		fade_in.tween_property(_logo_display, "modulate:a", 0.0, LOGO_FADE_TIME)
		fade_in.tween_callback(_start_intro_video)

		# Allow skip after brief delay
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree(): return
		_skippable = true
	else:
		_showing_logo = false
		_start_intro_video()

func _start_intro_video() -> void:
	_showing_logo = false
	if is_instance_valid(_logo_display):
		_logo_display.queue_free()

	_display.visible = true

	# Count available frames
	_total_frames = 0
	for i in range(1, FRAME_COUNT + 1):
		var path := FRAME_DIR + "frame_%04d.png" % i
		if ResourceLoader.exists(path):
			_total_frames += 1
		else:
			break

	if _total_frames == 0:
		push_warning("No intro frames found, skipping to menu")
		_go_to_menu()
		return

	# Show first frame
	_display.texture = _load_frame(1)
	_current_frame = 0

	# Frame advance timer
	_timer = Timer.new()
	_timer.wait_time = FRAME_DURATION
	_timer.one_shot = false
	_timer.timeout.connect(_next_frame)
	add_child(_timer)
	_timer.start()

	# Allow skip
	_skippable = true

func _load_frame(frame_num: int) -> Texture2D:
	var path := FRAME_DIR + "frame_%04d.png" % frame_num
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _next_frame() -> void:
	_current_frame += 1
	if _current_frame >= _total_frames:
		_timer.stop()
		_go_to_menu()
		return
	# Stream frame on demand instead of preloading all into memory
	var tex = _load_frame(_current_frame + 1)
	if not tex:
		_timer.stop()
		_go_to_menu()
		return
	# Crossfade with tween
	var tween := create_tween()
	_display.modulate.a = 0.7
	_display.texture = tex
	tween.tween_property(_display, "modulate:a", 1.0, 0.3)

func _unhandled_input(event: InputEvent) -> void:
	if not _skippable:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			_go_to_menu()

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
