extends CanvasLayer

const SYSTEMS := preload("res://scripts/systems.gd")
const SETTINGS_PATH := "user://settings.cfg"
const SURFACE := Color(0.078, 0.070, 0.094, 0.96)
const SURFACE_HIGH := Color(0.145, 0.133, 0.165, 0.98)
const ON_SURFACE := Color(0.902, 0.878, 0.918)
const ON_VARIANT := Color(0.780, 0.757, 0.816)
const ACCENTS := [
	{"name": "Фиолетовый", "primary": Color("#D0BCFF"), "container": Color("#4F378B"), "on": Color("#381E72"), "on_container": Color("#EADDFF")},
	{"name": "Синий", "primary": Color("#A8C7FA"), "container": Color("#0842A0"), "on": Color("#062E6F"), "on_container": Color("#D3E3FD")},
	{"name": "Зелёный", "primary": Color("#B7F2A8"), "container": Color("#2E6B2E"), "on": Color("#0E3A0E"), "on_container": Color("#D7F8D0")},
	{"name": "Бирюзовый", "primary": Color("#A0F0E0"), "container": Color("#006A60"), "on": Color("#003731"), "on_container": Color("#C8FFF4")},
	{"name": "Оранжевый", "primary": Color("#FFD8A8"), "container": Color("#8B5000"), "on": Color("#4A2800"), "on_container": Color("#FFE0C2")},
	{"name": "Розовый", "primary": Color("#FFB1C8"), "container": Color("#8E2A55"), "on": Color("#3B071F"), "on_container": Color("#FFD9E2")},
	{"name": "Красный", "primary": Color("#FFB4AB"), "container": Color("#93000A"), "on": Color("#410002"), "on_container": Color("#FFDAD6")},
	{"name": "Жёлтый", "primary": Color("#FFE082"), "container": Color("#6D5E00"), "on": Color("#3A3000"), "on_container": Color("#FFF0C2")},
]

signal action(action_name: String)

var _root: Control
var _title: Label
var _info: Label
var _pause_btn: Button
var _speed_label: Label
var _spawn_btn: Button
var _bar: PanelContainer
var _bar_grid: GridContainer
var _scenes_overlay: Control
var _scenes_panel: PanelContainer
var _scenes_scroll: ScrollContainer
var _scenes_grid: GridContainer
var _spawn_menu: Control
var _editor: PanelContainer
var _editor_title: Label
var _follow_btn: Button
var _visual_mode := "tail"
var _visual_buttons := {}
var _satellite_distance := 24.0
var _orbit_eccentricity := 0.0
var _show_barycenter := true
var _music_enabled := true
var _music_check: CheckButton
var _ecc_label: Label
var _ecc_slider: HSlider
var _sat_slider: HSlider
var _sat_label: Label
var _satellite_btn: Button
var _selected_is_star := false
var _hint: Label
var _hint_tween: Tween
var _scene_touch_id := -1
var _scene_scroll_moved := 0.0
var _settings_overlay: Control
var _settings_panel: PanelContainer
var _settings_btn: Button
var _buttons: Array[Button] = []
var _panels: Array[PanelContainer] = []
var _swatches: Array[Button] = []
var _accent_index := 0
var _primary := Color("#D0BCFF")
var _container := Color("#4F378B")
var _on_primary := Color("#381E72")
var _on_container := Color("#EADDFF")


func _ready() -> void:
	_build()


func _panel_style(alpha := 0.96) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(SURFACE.r, SURFACE.g, SURFACE.b, alpha)
	sb.border_color = Color(_primary.r, _primary.g, _primary.b, 0.16)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 5)
	return sb


func _button_style(kind: String, state: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	var base: Color
	var hover: Color
	var pressed: Color
	match kind:
		"primary":
			base = _container
			hover = _container.lightened(0.10)
			pressed = _container.lightened(0.18)
		"danger":
			base = Color(0.36, 0.10, 0.10, 1.0)
			hover = Color(0.46, 0.13, 0.13, 1.0)
			pressed = Color(0.55, 0.16, 0.16, 1.0)
		"icon":
			base = Color(0.0, 0.0, 0.0, 0.0)
			hover = Color(1.0, 1.0, 1.0, 0.08)
			pressed = Color(1.0, 1.0, 1.0, 0.14)
			sb.set_corner_radius_all(30)
			sb.content_margin_left = 0
			sb.content_margin_right = 0
			sb.content_margin_top = 0
			sb.content_margin_bottom = 0
		_:
			base = SURFACE_HIGH
			hover = SURFACE_HIGH.lightened(0.08)
			pressed = _container
	match state:
		"hover":
			sb.bg_color = hover
		"pressed", "hover_pressed":
			sb.bg_color = pressed
		_:
			sb.bg_color = base
	return sb


func _style_button(b: Button, kind: String) -> void:
	var active := bool(b.get_meta("active", false))
	var k := "primary" if active else kind
	b.add_theme_stylebox_override("normal", _button_style(k, "normal"))
	b.add_theme_stylebox_override("hover", _button_style(k, "hover"))
	b.add_theme_stylebox_override("pressed", _button_style(k, "pressed"))
	b.add_theme_stylebox_override("hover_pressed", _button_style(k, "hover_pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var fg := ON_SURFACE
	if k == "primary":
		fg = _on_container
	elif kind == "danger":
		fg = Color(1.0, 0.84, 0.82)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)


func _make_button(text: String, min_width := 0.0, kind := "tonal") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 94.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	b.set_meta("kind", kind)
	b.set_meta("active", false)
	_buttons.append(b)
	_style_button(b, kind)
	return b


func _set_button_active(b: Button, active: bool) -> void:
	if b == null:
		return
	b.set_meta("active", active)
	_style_button(b, str(b.get_meta("kind", "tonal")))


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		_accent_index = clampi(int(cf.get_value("ui", "accent", 0)), 0, ACCENTS.size() - 1)
		var mode := str(cf.get_value("ui", "visual", "tail"))
		_visual_mode = mode if mode in ["tail", "orbit", "none"] else "tail"
		_satellite_distance = clampf(float(cf.get_value("ui", "sat_dist", 24.0)), 12.0, 160.0)
		_orbit_eccentricity = clampf(float(cf.get_value("ui", "orbit_ecc", 0.0)), 0.0, 0.75)
		_show_barycenter = bool(cf.get_value("ui", "barycenter", true))
		_music_enabled = bool(cf.get_value("ui", "music", true))
	_apply_accent_vars()


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("ui", "accent", _accent_index)
	cf.set_value("ui", "visual", _visual_mode)
	cf.set_value("ui", "sat_dist", _satellite_distance)
	cf.set_value("ui", "orbit_ecc", _orbit_eccentricity)
	cf.set_value("ui", "barycenter", _show_barycenter)
	cf.set_value("ui", "music", _music_enabled)
	cf.save(SETTINGS_PATH)


func initial_visual_mode() -> String:
	return _visual_mode


func initial_satellite_distance() -> float:
	return _satellite_distance


func initial_orbit_eccentricity() -> float:
	return _orbit_eccentricity


func initial_barycenter() -> bool:
	return _show_barycenter


func initial_music_enabled() -> bool:
	return _music_enabled


func _apply_accent_vars() -> void:
	var a: Dictionary = ACCENTS[_accent_index]
	_primary = a["primary"]
	_container = a["container"]
	_on_primary = a["on"]
	_on_container = a["on_container"]


func _apply_accent_theme() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			_style_button(b, str(b.get_meta("kind", "tonal")))
	for p in _panels:
		if is_instance_valid(p):
			p.add_theme_stylebox_override("panel", _panel_style())
	if _title != null:
		_title.add_theme_color_override("font_color", _primary)
	if _info != null:
		_info.add_theme_color_override("font_color", ON_VARIANT)
	if _hint != null:
		_hint.add_theme_color_override("font_color", Color(ON_VARIANT.r, ON_VARIANT.g, ON_VARIANT.b, 0.92))
	if _speed_label != null:
		_speed_label.add_theme_color_override("font_color", ON_SURFACE)
		_speed_label.add_theme_stylebox_override("normal", _button_style("tonal", "normal"))
	_refresh_swatches()


func _build() -> void:
	_load_settings()
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", _panel_style(0.86))
	info_panel.offset_left = 22
	info_panel.offset_top = 22
	info_panel.offset_right = 22
	info_panel.offset_bottom = 22
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(info_panel)
	_panels.append(info_panel)

	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 4)
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(info_box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_child(top)

	_title = Label.new()
	_title.text = "Космос"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.custom_minimum_size = Vector2(0.0, 56.0)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", _primary)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_title)

	_settings_btn = _make_button("Настройки", 160.0, "tonal")
	_settings_btn.custom_minimum_size = Vector2(160.0, 56.0)
	_settings_btn.add_theme_font_size_override("font_size", 20)
	_settings_btn.pressed.connect(toggle_settings)
	top.add_child(_settings_btn)

	_info = Label.new()
	_info.text = ""
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_color", ON_VARIANT)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_child(_info)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _panel_style(0.94))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 14
	bar.offset_right = -14
	bar.offset_top = -160
	bar.offset_bottom = -14
	_bar = bar
	_panels.append(bar)

	_bar_grid = GridContainer.new()
	_bar_grid.columns = 8
	_bar_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_grid.add_theme_constant_override("h_separation", 10)
	_bar_grid.add_theme_constant_override("v_separation", 10)
	bar.add_child(_bar_grid)

	_pause_btn = _make_button("Пауза", 0.0, "primary")
	_pause_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_btn.pressed.connect(_emit.bind("pause"))
	_bar_grid.add_child(_pause_btn)

	var minus := _make_button("−", 72)
	minus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minus.pressed.connect(_emit.bind("speed_down"))
	_bar_grid.add_child(minus)

	_speed_label = Label.new()
	_speed_label.custom_minimum_size = Vector2(104, 94)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_label.add_theme_font_size_override("font_size", 30)
	_speed_label.add_theme_color_override("font_color", ON_SURFACE)
	_speed_label.add_theme_stylebox_override("normal", _button_style("tonal", "normal"))
	_bar_grid.add_child(_speed_label)

	var plus := _make_button("+", 72)
	plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plus.pressed.connect(_emit.bind("speed_up"))
	_bar_grid.add_child(plus)

	_spawn_btn = _make_button("Тело", 118, "primary")
	_spawn_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spawn_btn.pressed.connect(_emit.bind("spawn"))
	_bar_grid.add_child(_spawn_btn)

	var scenes_btn := _make_button("Сцены", 118, "primary")
	scenes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scenes_btn.pressed.connect(_emit.bind("scenes"))
	_bar_grid.add_child(scenes_btn)

	var center_btn := _make_button("Центр", 118)
	center_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_btn.pressed.connect(_emit.bind("center"))
	_bar_grid.add_child(center_btn)

	var reset_btn := _make_button("Сброс", 118)
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_emit.bind("reset"))
	_bar_grid.add_child(reset_btn)

	_hint = Label.new()
	_root.add_child(_hint)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_left = 30
	_hint.offset_right = -30
	_hint.offset_top = -206
	_hint.offset_bottom = -160
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(ON_VARIANT.r, ON_VARIANT.g, ON_VARIANT.b, 0.92))

	_build_editor()
	_build_spawn_menu()
	_build_scenes_overlay()
	_build_settings_overlay()
	_apply_layout()
	_apply_accent_theme()
	get_viewport().size_changed.connect(_apply_layout)


func _apply_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.y > vp.x
	var bar_h := 238.0 if portrait else 160.0
	if _bar_grid != null:
		_bar_grid.columns = 4 if portrait else 8
	if _bar != null:
		_bar.offset_top = -bar_h
		_bar.offset_bottom = -14
	if _hint != null:
		_hint.offset_top = -bar_h - 60.0
		_hint.offset_bottom = -bar_h - 10.0
	if _scenes_grid != null:
		_scenes_grid.columns = 2 if portrait else 3
	if _editor != null:
		_editor.offset_left = -370.0
		_editor.offset_right = -22.0
		_editor.offset_top = 22.0
		_editor.offset_bottom = 540.0


func _build_editor() -> void:
	_editor = PanelContainer.new()
	_editor.add_theme_stylebox_override("panel", _panel_style(0.94))
	_editor.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_editor)
	_editor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_editor.offset_left = -370
	_editor.offset_top = 22
	_editor.offset_right = -22
	_editor.offset_bottom = 540
	_editor.visible = false
	_panels.append(_editor)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_editor.add_child(box)

	_editor_title = Label.new()
	_editor_title.text = "Объект"
	_editor_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_editor_title.add_theme_font_size_override("font_size", 28)
	_editor_title.add_theme_color_override("font_color", ON_SURFACE)
	_editor_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_editor_title)

	var sat_box := VBoxContainer.new()
	sat_box.add_theme_constant_override("separation", 2)
	sat_box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(sat_box)

	_sat_label = Label.new()
	_sat_label.text = "Спутник: %.0f" % _satellite_distance
	_sat_label.add_theme_font_size_override("font_size", 20)
	_sat_label.add_theme_color_override("font_color", ON_VARIANT)
	_sat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sat_box.add_child(_sat_label)

	_sat_slider = HSlider.new()
	_sat_slider.min_value = 12.0
	_sat_slider.max_value = 160.0
	_sat_slider.step = 1.0
	_sat_slider.value = _satellite_distance
	_sat_slider.custom_minimum_size = Vector2(0.0, 44.0)
	_sat_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sat_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_sat_slider.value_changed.connect(_on_sat_distance_changed)
	sat_box.add_child(_sat_slider)

	var sat_controls := HBoxContainer.new()
	sat_controls.add_theme_constant_override("separation", 8)
	sat_controls.mouse_filter = Control.MOUSE_FILTER_STOP
	var minus := _make_button("−", 120)
	minus.custom_minimum_size = Vector2(120.0, 50.0)
	minus.add_theme_font_size_override("font_size", 26)
	minus.pressed.connect(_on_sat_step.bind(-5.0))
	sat_controls.add_child(minus)
	var plus := _make_button("+", 120)
	plus.custom_minimum_size = Vector2(120.0, 50.0)
	plus.add_theme_font_size_override("font_size", 26)
	plus.pressed.connect(_on_sat_step.bind(5.0))
	sat_controls.add_child(plus)
	sat_box.add_child(sat_controls)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)

	var entries := [
		["satellite", "Спутник"],
		["mass_up", "Масса +"],
		["mass_down", "Масса −"],
		["recolor", "Цвет"],
		["follow", "Следить"],
		["delete", "Удалить"],
		["deselect", "Снять выбор"],
	]
	for e in entries:
		var kind := "danger" if e[0] == "delete" else "tonal"
		var b := _make_button(e[1], 150.0, kind)
		b.custom_minimum_size = Vector2(150.0, 76.0)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_emit.bind(e[0]))
		grid.add_child(b)
		if e[0] == "satellite":
			_satellite_btn = b
		elif e[0] == "follow":
			_follow_btn = b
	_refresh_satellite_labels()


func _refresh_satellite_labels() -> void:
	var noun := "Планета" if _selected_is_star else "Спутник"
	if _satellite_btn != null:
		_satellite_btn.text = noun
	if _sat_label != null:
		_sat_label.text = "%s: %.0f" % [noun, _satellite_distance]


func _build_spawn_menu() -> void:
	_spawn_menu = Control.new()
	_root.add_child(_spawn_menu)
	_spawn_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spawn_menu.visible = false
	_spawn_menu.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	_spawn_menu.add_child(dim)
	dim.color = Color(0.0, 0.0, 0.02, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_spawn_dim_input)

	var center := CenterContainer.new()
	_spawn_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.98))
	center.add_child(panel)
	_panels.append(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var title := Label.new()
	title.text = "Что создать?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", ON_SURFACE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)

	var entries := [
		["spawn:planet", "Планета"],
		["spawn:star", "Звезда"],
		["spawn:asteroid", "Астероид"],
		["spawn:off", "Выключить"],
	]
	for e in entries:
		var b := _make_button(e[1], 220.0)
		b.custom_minimum_size = Vector2(220.0, 88.0)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_on_spawn_choice.bind(e[0]))
		grid.add_child(b)

	var close := _make_button("Отмена", 210.0)
	close.custom_minimum_size = Vector2(220.0, 88.0)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(_close_spawn_menu)
	grid.add_child(close)


func _on_spawn_choice(action_name: String) -> void:
	_spawn_menu.visible = false
	action.emit(action_name)


func _on_spawn_dim_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		_spawn_menu.visible = false
	elif event is InputEventScreenTouch and event.pressed:
		_spawn_menu.visible = false


func _close_spawn_menu() -> void:
	_spawn_menu.visible = false


func open_spawn_menu() -> void:
	_spawn_menu.visible = true


func _build_scenes_overlay() -> void:
	_scenes_overlay = Control.new()
	_root.add_child(_scenes_overlay)
	_scenes_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scenes_overlay.visible = false
	_scenes_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	_scenes_overlay.add_child(dim)
	dim.color = Color(0.0, 0.0, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)

	_scenes_panel = PanelContainer.new()
	_scenes_overlay.add_child(_scenes_panel)
	_scenes_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scenes_panel.offset_left = 24
	_scenes_panel.offset_top = 32
	_scenes_panel.offset_right = -24
	_scenes_panel.offset_bottom = -32
	_scenes_panel.add_theme_stylebox_override("panel", _panel_style(0.98))
	_panels.append(_scenes_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_scenes_panel.add_child(box)

	var title := Label.new()
	title.text = "Выберите сцену"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", ON_SURFACE)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "8 базовых и %d систем · свайпайте или листайте" % SYSTEMS.LIST.size()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", ON_VARIANT)
	box.add_child(sub)

	_scenes_scroll = ScrollContainer.new()
	_scenes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scenes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scenes_scroll)
	var vs := _scenes_scroll.get_v_scroll_bar()
	vs.custom_minimum_size.x = 18.0

	_scenes_grid = GridContainer.new()
	_scenes_grid.columns = 2
	_scenes_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scenes_grid.add_theme_constant_override("h_separation", 12)
	_scenes_grid.add_theme_constant_override("v_separation", 12)
	_scenes_scroll.add_child(_scenes_grid)

	var entries := [
		["solar", "Солнечная система"],
		["binary", "Двойная звезда"],
		["ring", "Кольцо астероидов"],
		["collision", "Столкновение"],
		["comet", "Комета"],
		["tidal", "Приливной разрыв"],
		["moons", "Планета и луны"],
		["empty", "Пустая система"],
	]
	for sys in SYSTEMS.LIST:
		entries.append([str(sys["id"]), str(sys["name"])])
	for e in entries:
		var b := _make_button(str(e[1]), 250.0)
		b.custom_minimum_size = Vector2(250.0, 86.0)
		b.add_theme_font_size_override("font_size", 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_preset_pressed.bind(str(e[0])))
		_scenes_grid.add_child(b)

	var close := _make_button("Закрыть", 250.0)
	close.custom_minimum_size = Vector2(250.0, 86.0)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(_close_scenes)
	box.add_child(close)


func _build_settings_overlay() -> void:
	_settings_overlay = Control.new()
	_root.add_child(_settings_overlay)
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.visible = false
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	_settings_overlay.add_child(dim)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_settings_dim_input)

	var center := CenterContainer.new()
	_settings_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_settings_panel = PanelContainer.new()
	_settings_panel.custom_minimum_size = Vector2(760.0, 0.0)
	_settings_panel.add_theme_stylebox_override("panel", _panel_style(0.98))
	center.add_child(_settings_panel)
	_panels.append(_settings_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(box)

	var title := Label.new()
	title.text = "Настройки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ON_SURFACE)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Акцентный цвет Material You"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", ON_VARIANT)
	box.add_child(sub)

	var view_label := Label.new()
	view_label.text = "Вид траекторий"
	view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_label.add_theme_font_size_override("font_size", 22)
	view_label.add_theme_color_override("font_color", ON_VARIANT)
	box.add_child(view_label)

	var view_grid := GridContainer.new()
	view_grid.columns = 3
	view_grid.add_theme_constant_override("h_separation", 14)
	view_grid.add_theme_constant_override("v_separation", 14)
	box.add_child(view_grid)
	for entry in [["tail", "Хвост"], ["orbit", "Орбита"], ["none", "Нет"]]:
		var vb := _make_button(entry[1], 180.0)
		vb.custom_minimum_size = Vector2(180.0, 76.0)
		vb.add_theme_font_size_override("font_size", 22)
		vb.pressed.connect(_on_visual_mode_pressed.bind(entry[0]))
		view_grid.add_child(vb)
		_visual_buttons[entry[0]] = vb

	var ecc_box := VBoxContainer.new()
	ecc_box.add_theme_constant_override("separation", 2)
	ecc_box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(ecc_box)

	_ecc_label = Label.new()
	_ecc_label.text = "Вытянутость орбиты: %d%%" % roundi(_orbit_eccentricity * 100.0)
	_ecc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ecc_label.add_theme_font_size_override("font_size", 22)
	_ecc_label.add_theme_color_override("font_color", ON_VARIANT)
	_ecc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ecc_box.add_child(_ecc_label)

	_ecc_slider = HSlider.new()
	_ecc_slider.min_value = 0.0
	_ecc_slider.max_value = 0.75
	_ecc_slider.step = 0.05
	_ecc_slider.value = _orbit_eccentricity
	_ecc_slider.custom_minimum_size = Vector2(0.0, 44.0)
	_ecc_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ecc_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_ecc_slider.value_changed.connect(_on_orbit_eccentricity_changed)
	ecc_box.add_child(_ecc_slider)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)

	for i in ACCENTS.size():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		grid.add_child(cell)

		var sw := Button.new()
		sw.custom_minimum_size = Vector2(120.0, 88.0)
		sw.focus_mode = Control.FOCUS_NONE
		sw.toggle_mode = true
		sw.set_meta("accent_index", i)
		sw.pressed.connect(_on_swatch_pressed.bind(i))
		_swatches.append(sw)
		cell.add_child(sw)

		var lbl := Label.new()
		lbl.text = str(ACCENTS[i]["name"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", ON_VARIANT)
		cell.add_child(lbl)

	var bary := CheckButton.new()
	bary.text = "Показывать барицентр"
	bary.button_pressed = _show_barycenter
	bary.add_theme_font_size_override("font_size", 24)
	bary.add_theme_color_override("font_color", ON_SURFACE)
	bary.toggled.connect(_on_barycenter_toggled)
	box.add_child(bary)

	_music_check = CheckButton.new()
	_music_check.text = "Музыка космоса"
	_music_check.button_pressed = _music_enabled
	_music_check.add_theme_font_size_override("font_size", 24)
	_music_check.add_theme_color_override("font_color", ON_SURFACE)
	_music_check.toggled.connect(_on_music_toggled)
	box.add_child(_music_check)

	var close := _make_button("Готово", 240.0, "primary")
	close.custom_minimum_size = Vector2(240.0, 88.0)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(_close_settings)
	box.add_child(close)

	_refresh_swatches()
	set_visual_mode(_visual_mode)


func _style_swatch(sw: Button, i: int) -> void:
	var c: Color = ACCENTS[i]["primary"]
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(24)
	var selected := i == _accent_index
	if selected:
		sb.border_color = Color(1.0, 1.0, 1.0, 0.95)
		sb.set_border_width_all(4)
		sw.text = "✓"
	else:
		sb.border_color = Color(0.0, 0.0, 0.0, 0.0)
		sb.set_border_width_all(0)
		sw.text = ""
	sw.add_theme_stylebox_override("normal", sb)
	sw.add_theme_stylebox_override("hover", sb)
	sw.add_theme_stylebox_override("pressed", sb)
	sw.add_theme_stylebox_override("hover_pressed", sb)
	sw.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	sw.add_theme_color_override("font_color", Color(0.12, 0.10, 0.14))
	sw.add_theme_color_override("font_hover_color", Color(0.12, 0.10, 0.14))
	sw.add_theme_color_override("font_pressed_color", Color(0.12, 0.10, 0.14))
	sw.button_pressed = selected


func _refresh_swatches() -> void:
	for i in _swatches.size():
		_style_swatch(_swatches[i], i)


func _on_swatch_pressed(i: int) -> void:
	_accent_index = i
	_apply_accent_vars()
	_save_settings()
	_apply_accent_theme()


func _on_settings_dim_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_settings()
	elif event is InputEventScreenTouch and event.pressed:
		_close_settings()


func _close_settings() -> void:
	_settings_overlay.visible = false


func toggle_settings() -> void:
	_settings_overlay.visible = not _settings_overlay.visible


func _input(event: InputEvent) -> void:
	if _scenes_overlay == null or not _scenes_overlay.visible:
		return
	if _settings_overlay != null and _settings_overlay.visible:
		return
	if _spawn_menu != null and _spawn_menu.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _scene_touch_id == -1:
				_scene_touch_id = event.index
				_scene_scroll_moved = 0.0
		else:
			if event.index == _scene_touch_id:
				_scene_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == _scene_touch_id:
			_scene_scroll_moved += event.relative.length()
			if _scene_scroll_moved > 12.0 and _scenes_scroll != null:
				_scenes_scroll.scroll_vertical -= int(event.relative.y)
				get_viewport().set_input_as_handled()


func _emit(action_name: String) -> void:
	action.emit(action_name)


func _on_preset_pressed(id: String) -> void:
	if _scene_scroll_moved > 20.0:
		_scene_scroll_moved = 0.0
		return
	action.emit("preset:" + id)
	_scenes_overlay.visible = false


func _close_scenes() -> void:
	if _scene_scroll_moved > 20.0:
		_scene_scroll_moved = 0.0
		return
	_scenes_overlay.visible = false


func _on_dim_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		_scenes_overlay.visible = false
	elif event is InputEventScreenTouch and event.pressed:
		_scenes_overlay.visible = false


func toggle_scenes() -> void:
	_scene_touch_id = -1
	_scene_scroll_moved = 0.0
	_scenes_overlay.visible = not _scenes_overlay.visible


func set_info(text: String) -> void:
	_info.text = text


func set_paused(p: bool) -> void:
	_pause_btn.text = "Пуск" if p else "Пауза"


func set_speed(v: float) -> void:
	var txt := ""
	if absf(v - roundf(v)) < 0.001:
		txt = str(int(roundf(v)))
	else:
		txt = "%.2f" % v
	_speed_label.text = "×" + txt


func set_spawn(on: bool, kind_name: String) -> void:
	_spawn_btn.text = kind_name if on else "Тело"
	_set_button_active(_spawn_btn, on)


func set_selection(has_selection: bool, title: String, following: bool, is_star: bool = false) -> void:
	_editor.visible = has_selection
	if has_selection:
		_editor_title.text = title
		_selected_is_star = is_star
		_refresh_satellite_labels()
		if _follow_btn != null:
			_set_button_active(_follow_btn, following)


func set_visual_mode(mode: String) -> void:
	_visual_mode = mode
	for key in _visual_buttons.keys():
		_set_button_active(_visual_buttons[key], key == mode)


func _on_visual_mode_pressed(mode: String) -> void:
	set_visual_mode(mode)
	_save_settings()
	action.emit("visual:" + mode)


func _on_orbit_eccentricity_changed(v: float) -> void:
	_orbit_eccentricity = roundf(v / 0.05) * 0.05
	if _ecc_slider != null:
		_ecc_slider.set_value_no_signal(_orbit_eccentricity)
	if _ecc_label != null:
		_ecc_label.text = "Вытянутость орбиты: %d%%" % roundi(_orbit_eccentricity * 100.0)
	_save_settings()
	action.emit("ecc:%.2f" % _orbit_eccentricity)


func _on_sat_distance_changed(v: float) -> void:
	_satellite_distance = roundf(v)
	if _sat_slider != null:
		_sat_slider.set_value_no_signal(_satellite_distance)
	_refresh_satellite_labels()
	_save_settings()
	action.emit("sat_dist:%.0f" % _satellite_distance)


func _on_sat_step(delta: float) -> void:
	_on_sat_distance_changed(clampf(_satellite_distance + delta, 12.0, 160.0))



func _on_barycenter_toggled(on: bool) -> void:
	_show_barycenter = on
	_save_settings()
	action.emit("barycenter:" + ("1" if on else "0"))


func _on_music_toggled(on: bool) -> void:
	_music_enabled = on
	_save_settings()
	action.emit("music:" + ("1" if on else "0"))


func show_hint(text: String) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(5.5)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.4)
