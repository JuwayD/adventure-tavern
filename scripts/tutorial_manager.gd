extends CanvasLayer

## 新手教程系统 - 引导玩家了解游戏基本操作

signal tutorial_step_completed(step_id: int)
signal tutorial_finished()

enum TutorialStep {
	WELCOME = 0,           # 欢迎界面
	FIRST_DAY = 1,        # 开始第一天
	BUILD_TABLE = 2,      # 建造餐桌
	PLACE_FACILITY = 3,   # 放置设施
	WAIT_GUEST = 4,       # 等待客人
	CLICK_GUEST = 5,      # 点击客人
	SERVE_GUEST = 6,      # 服务客人
	COMPLETE = 7          # 教程完成
}

const STEP_DEFINITIONS: Array = [
	{
		"id": TutorialStep.WELCOME,
		"title": "欢迎来到冒险者酒馆！",
		"text": "欢迎来到冒险者酒馆！在这款模拟经营肉鸽建造游戏中，你将经营一家酒馆接待形形色色的冒险者。\n\n点击「知道了」开始教程。",
		"highlight": "",
		"action": "dismiss"
	},
	{
		"id": TutorialStep.FIRST_DAY,
		"title": "第一天开始了",
		"text": "每天开始时，你可以从3张卡牌中选择1张获得加成。\n\n请先选择一张卡牌，然后点击右下角的「下一天」按钮进入第一天。",
		"highlight": "NextDayButton",
		"action": "next_day"
	},
	{
		"id": TutorialStep.BUILD_TABLE,
		"title": "建造设施",
		"text": "酒馆需要设施来接待客人！\n\n点击右侧面板的「🍽️ 餐桌」按钮来建造餐桌。餐桌是接待客人的基本设施。",
		"highlight": "BuildPanel",
		"action": "build_table"
	},
	{
		"id": TutorialStep.PLACE_FACILITY,
		"title": "放置设施",
		"text": "现在点击酒馆内的空格子（绿色高亮处）来放置餐桌。",
		"highlight": "tavern_floor",
		"action": "place_facility"
	},
	{
		"id": TutorialStep.WAIT_GUEST,
		"title": "等待客人",
		"text": "太好了！餐桌已经放置好了。\n\n点击「下一天」按钮，客人们就会陆续到来。",
		"highlight": "NextDayButton",
		"action": "wait_guest"
	},
	{
		"id": TutorialStep.CLICK_GUEST,
		"title": "接待客人",
		"text": "有客人来了！\n\n点击酒馆中的客人（圆圈图标），查看他们需要什么服务。",
		"highlight": "tavern_floor",
		"action": "click_guest"
	},
	{
		"id": TutorialStep.SERVE_GUEST,
		"title": "提供服务",
		"text": "客人想要食物或饮料！\n\n在客人详情面板中点击「🍽️ 提供服务」来满足客人的需求，获得金币和声誉奖励。",
		"highlight": "GuestDetailPanel",
		"action": "serve_guest"
	},
	{
		"id": TutorialStep.COMPLETE,
		"title": "教程完成！",
		"text": "太棒了！你已经学会了基本操作。\n\n记住：\n• 建造更多设施吸引更多客人\n• 雇佣员工提升效率\n• 每天选择有利的卡牌\n• 关注金币、声誉、食材和燃料\n\n祝你的酒馆繁荣昌盛！🍺",
		"highlight": "",
		"action": "dismiss"
	}
]

var current_step: int = -1
var tutorial_panel: PanelContainer
var tutorial_title: Label
var tutorial_text: Label
var tutorial_button: Button
var highlight_rect: ColorRect
var arrowIndicator: Label
var is_tutorial_active: bool = false
var tutorial_data: Dictionary = {}
var staff_button_highlighted: bool = false

func _ready() -> void:
	_create_tutorial_ui()
	_hide_tutorial()

func _create_tutorial_ui() -> void:
	# Tutorial panel
	tutorial_panel = PanelContainer.new()
	tutorial_panel.set_anchors_preset(Control.PRESET_CENTER)
	tutorial_panel.custom_minimum_size = Vector2(500, 280)
	tutorial_panel.z_index = 100
	add_child(tutorial_panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.12, 0.1, 0.95)
	panel_style.border_color = Color(0.8, 0.6, 0.3, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 20
	panel_style.content_margin_top = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_bottom = 20
	tutorial_panel.add_theme_stylebox_override("panel", panel_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	tutorial_panel.add_child(vbox)
	
	# Title
	tutorial_title = Label.new()
	tutorial_title.text = "教程"
	tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_title.add_theme_font_size_override("font_size", 24)
	tutorial_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(tutorial_title)
	
	# Text
	tutorial_text = Label.new()
	tutorial_text.text = ""
	tutorial_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	tutorial_text.custom_minimum_size = Vector2(460, 0)
	tutorial_text.add_theme_font_size_override("font_size", 16)
	tutorial_text.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	vbox.add_child(tutorial_text)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Button
	tutorial_button = Button.new()
	tutorial_button.text = "知道了"
	tutorial_button.custom_minimum_size = Vector2(150, 45)
	tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.5, 0.3)
	btn_style.border_color = Color(0.4, 0.7, 0.4)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	tutorial_button.add_theme_stylebox_override("normal", btn_style)
	tutorial_button.add_theme_stylebox_override("hover", btn_style)
	tutorial_button.add_theme_stylebox_override("pressed", btn_style)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(tutorial_button)
	vbox.add_child(hbox)
	
	# Highlight overlay
	highlight_rect = ColorRect.new()
	highlight_rect.color = Color(0, 0, 0, 0)
	highlight_rect.z_index = 99
	add_child(highlight_rect)
	
	# Arrow indicator
	arrowIndicator = Label.new()
	arrowIndicator.text = "▼"
	arrowIndicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrowIndicator.add_theme_font_size_override("font_size", 32)
	arrowIndicator.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 0.9))
	arrowIndicator.z_index = 101
	arrowIndicator.visible = false
	add_child(arrowIndicator)

func show_tutorial() -> void:
	if current_step < 0 or current_step >= STEP_DEFINITIONS.size():
		return
	
	var step_data = STEP_DEFINITIONS[current_step]
	tutorial_title.text = step_data["title"]
	tutorial_text.text = step_data["text"]
	tutorial_panel.visible = true
	
	# Update button text based on action
	match step_data["action"]:
		"next_day":
			tutorial_button.text = "跳过教程"
		"build_table":
			tutorial_button.text = "跳过教程"
		"place_facility":
			tutorial_button.text = "取消建造"
		"wait_guest":
			tutorial_button.text = "跳过教程"
		"click_guest":
			tutorial_button.text = "跳过教程"
		"serve_guest":
			tutorial_button.text = "跳过教程"
		"dismiss":
			tutorial_button.text = "知道了"
		_:
			tutorial_button.text = "知道了"
	
	is_tutorial_active = true
	_update_highlight(step_data["highlight"])

func _update_highlight(highlight_target: String) -> void:
	if highlight_target == "":
		highlight_rect.visible = false
		arrowIndicator.visible = false
		return
	
	var target_node = _find_node_by_name(highlight_target)
	if target_node == null:
		highlight_rect.visible = false
		arrowIndicator.visible = false
		return
	
	var global_pos = target_node.global_position
	var size = _get_node_size(target_node)
	
	# Create a highlight border around the target
	highlight_rect.visible = true
	highlight_rect.position = global_pos - Vector2(5, 5)
	highlight_rect.custom_minimum_size = size + Vector2(10, 10)
	
	# Show arrow pointing to target
	arrowIndicator.visible = true
	arrowIndicator.position = global_pos + Vector2(size.x / 2 - 10, -40)

func _find_node_by_name(node_name: String) -> Node:
	var main = get_node_or_null("/root/Main")
	if main == null:
		return null
	
	match node_name:
		"NextDayButton":
			return main.get_node_or_null("UI/NextDayButton")
		"BuildPanel":
			return main.get_node_or_null("UI/BuildPanel")
		"GuestDetailPanel":
			return main.get_node_or_null("UI/GuestDetailPanel")
		"tavern_floor":
			return main.get_node_or_null("TavernFloor")
		_:
			return null

func _get_node_size(node: Node) -> Vector2:
	if node is Control:
		return node.size
	elif node is Node2D:
		return Vector2(200, 200)  # Approximate size for Node2D
	return Vector2(100, 100)

func _hide_tutorial() -> void:
	tutorial_panel.visible = false
	highlight_rect.visible = false
	arrowIndicator.visible = false
	is_tutorial_active = false

func _on_tutorial_button_pressed() -> void:
	if current_step < 0 or current_step >= STEP_DEFINITIONS.size():
		_hide_tutorial()
		return
	
	var step_data = STEP_DEFINITIONS[current_step]
	var action = step_data["action"]
	
	# Handle skip
	if action in ["next_day", "build_table", "wait_guest", "click_guest", "serve_guest"]:
		_skip_tutorial()
		return
	
	# Handle place facility cancel
	if action == "place_facility":
		_cancel_build_mode()
		_skip_tutorial()
		return
	
	# Just advance
	_advance_tutorial()

func _advance_tutorial() -> void:
	tutorial_data["step_" + str(current_step)] = true
	emit_signal("tutorial_step_completed", current_step)
	
	current_step += 1
	if current_step >= STEP_DEFINITIONS.size():
		_finish_tutorial()
	else:
		show_tutorial()

func _skip_tutorial() -> void:
	tutorial_data["skipped"] = true
	_cancel_build_mode()
	_finish_tutorial()

func _finish_tutorial() -> void:
	tutorial_data["completed"] = true
	_hide_tutorial()
	is_tutorial_active = false
	emit_signal("tutorial_finished")
	print("[Tutorial] Tutorial finished or skipped")

func _cancel_build_mode() -> void:
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("cancel_build_mode"):
		main.cancel_build_mode()

func start_tutorial() -> void:
	if tutorial_data.get("completed", false) or tutorial_data.get("skipped", false):
		return  # Already completed or skipped
	
	current_step = TutorialStep.WELCOME
	show_tutorial()

func notify_event(event_name: String) -> void:
	if not is_tutorial_active:
		return
	
	var step_data = STEP_DEFINITIONS[current_step]
	if step_data["action"] != event_name:
		return
	
	# Special handling for place_facility
	if event_name == "place_facility" and current_step == TutorialStep.PLACE_FACILITY:
		_advance_tutorial()
		return
	
	# For other events, advance when the button is pressed
	match event_name:
		"build_table":
			# Wait for player to enter build mode, then advance
			pass
		"wait_guest":
			# Advance to next step when next day is clicked
			pass

func notify_build_mode_entered() -> void:
	if is_tutorial_active and current_step == TutorialStep.BUILD_TABLE:
		_advance_tutorial()

func notify_facility_placed() -> void:
	if is_tutorial_active and current_step == TutorialStep.PLACE_FACILITY:
		_advance_tutorial()

func notify_guest_clicked() -> void:
	if is_tutorial_active and current_step == TutorialStep.CLICK_GUEST:
		_advance_tutorial()

func notify_guest_served() -> void:
	if is_tutorial_active and current_step == TutorialStep.SERVE_GUEST:
		_advance_tutorial()

func notify_next_day() -> void:
	if is_tutorial_active:
		match current_step:
			TutorialStep.FIRST_DAY:
				_advance_tutorial()
			TutorialStep.WAIT_GUEST:
				_advance_tutorial()

func notify_card_selected() -> void:
	# Cards have been selected, advance if on card selection step
	pass

func save_tutorial_data() -> Dictionary:
	return tutorial_data

func load_tutorial_data(data: Dictionary) -> void:
	tutorial_data = data

func is_tutorial_completed() -> bool:
	return tutorial_data.get("completed", false) or tutorial_data.get("skipped", false)

func reset_tutorial() -> void:
	tutorial_data = {}
	current_step = -1
	is_tutorial_active = false
	_hide_tutorial()
