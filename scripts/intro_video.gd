extends Control

## Plays the intro as a frame-by-frame slideshow, then transitions to main menu.
## Press any key or click to skip.

const FRAME_DIR := "res://assets/video/frames/"
const FRAME_COUNT := 552
const FRAME_DURATION := 0.1  # 10fps playback to match extraction rate

var _display: TextureRect
var _skippable := false
var _current_frame := 0
var _total_frames := 0
var _timer: Timer

func _ready() -> void:
	# Black background
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Frame display
	_display = TextureRect.new()
	_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_display)

	# Count available frames (don't load them all — stream on demand)
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

	# Small delay before allowing skip
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree(): return
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
