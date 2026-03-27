extends CanvasLayer

## UI 管理器

signal build_requested(facility_type: String)
signal next_day_requested()
signal guest_selected(guest_id: int)
signal card_selected(card_index: int)
signal save_requested()
signal load_requested()

@onready var gold_label: Label = $ResourcePanel/VBox/GoldValue
@onready var rep_label: Label = $ResourcePanel/VBox/RepValue
@onready var ing_label: Label = $ResourcePanel/VBox/IngValue
@onready var fuel_label: Label = $ResourcePanel/VBox/FuelValue
@onready var day_label: Label = $DayLabel
@onready var message_label: Label = $MessageLabel
@onready var event_panel: PanelContainer = $EventPanel
@onready var event_label: Label = $EventPanel/EventLabel
@onready var build_panel: VBoxContainer = $BuildPanel
@onready var guest_panel: PanelContainer = $GuestPanel
@onready var guest_list: ItemList = $GuestPanel/GuestList
@onready var card_panel: PanelContainer = $CardPanel
@onready var guest_detail_panel: PanelContainer = $GuestDetailPanel

var current_message: String = ""
var message_timer: float = 0.0
var build_mode: bool = false
var current_guest_id: int = -1
var tutorial: Node = null
var visual_effects: Node = null

func _ready() -> void:
	# Get tutorial reference
	tutorial = get_node_or_null("/root/Main/TutorialManager")
	visual_effects = get_node_or_null("/root/Main/VisualEffects")
	_update_visibility()
	event_panel.visible = false
	build_panel.visible = true  # 建造面板默认显示
	guest_panel.visible = false
	card_panel.visible = false
	guest_detail_panel.visible = false
	
	# 确保资源面板可见
	var resource_panel: PanelContainer = $ResourcePanel
	if resource_panel:
		resource_panel.visible = true

func _process(delta: float) -> void:
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_label.text = ""

func update_resources(gold: int, reputation: int, ingredients: int, fuel: int) -> void:
	gold_label.text = "💰 " + str(gold)
	rep_label.text = "⭐ " + str(reputation)
	ing_label.text = "🥬 " + str(ingredients)
	fuel_label.text = "🔥 " + str(fuel)
	
	# 资源警告：当资源过低时显示醒目颜色
	var warn_color: Color = Color(1.0, 0.3, 0.3)
	var safe_color: Color = Color(1, 1, 1)
	
	if reputation <= 20:
		rep_label.add_theme_color_override("font_color", warn_color)
	elif reputation <= 40:
		rep_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		rep_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	
	if ingredients <= 5:
		ing_label.add_theme_color_override("font_color", warn_color)
	elif ingredients <= 10:
		ing_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		ing_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.4))
	
	if fuel <= 3:
		fuel_label.add_theme_color_override("font_color", warn_color)
	elif fuel <= 6:
		fuel_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		fuel_label.add_theme_color_override("font_color", Color(1, 0.5, 0.3))
	
	if gold <= 10:
		gold_label.add_theme_color_override("font_color", warn_color)
	elif gold <= 30:
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))

func update_day(day: int) -> void:
	day_label.text = "第 %d 天" % day

func show_message(msg: String, duration: float = 3.0) -> void:
	message_label.text = msg
	message_timer = duration

func show_event(event_type: String, event_data: Dictionary) -> void:
	event_panel.visible = true
	var msg: String = event_data.get("msg", "事件发生")
	event_label.text = msg
	
	match event_type:
		"good":
			event_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		"bad":
			event_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		_:
			event_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	
	await get_tree().create_timer(3.0).timeout
	event_panel.visible = false

func show_build_panel(available_facilities: Array, player_gold: int) -> void:
	build_panel.visible = true

func hide_build_panel() -> void:
	build_panel.visible = false

func show_guest_panel(guests: Array) -> void:
	guest_panel.visible = true
	guest_list.clear()
	for guest in guests:
		var guest_type: String = guest.get("type", "common")
		var order: Dictionary = guest.get("order", {})
		var order_str: String = ""
		if order.get("food", 0) > 0:
			order_str += "🍖x%d " % order["food"]
		if order.get("drink", 0) > 0:
			order_str += "🍺x%d " % order["drink"]
		if order.get("luxury", 0) > 0:
			order_str += "💎x%d" % order["luxury"]
		if order_str == "":
			order_str = "已满足"
		guest_list.add_item("[%s] %s" % [guest_type, order_str])

func hide_guest_panel() -> void:
	guest_panel.visible = false

func show_guest_detail(guest: Dictionary) -> void:
	"""显示客人详情面板"""
	current_guest_id = int(guest.get("id", -1))
	guest_detail_panel.visible = true
	# 面板弹出动画
	if visual_effects and visual_effects.has_method("animate_panel_popup"):
		visual_effects.animate_panel_popup(guest_detail_panel)
	
	var guest_type: String = guest.get("type", "common")
	var order: Dictionary = guest.get("order", {})
	
	var type_label: Label = $GuestDetailPanel/GuestTypeLabel
	type_label.text = "类型: %s" % guest_type
	
	# 显示订单
	var order_text: String = "订单:\n"
	var has_order: bool = false
	if order.get("food", 0) > 0:
		order_text += "  🍖 食物 x%d\n" % order["food"]
		has_order = true
	if order.get("drink", 0) > 0:
		order_text += "  🍺 酒水 x%d\n" % order["drink"]
		has_order = true
	if order.get("luxury", 0) > 0:
		order_text += "  💎 奢侈品 x%d\n" % order["luxury"]
		has_order = true
	
	if not has_order:
		order_text += "  (无)"
	
	var order_label: Label = $GuestDetailPanel/OrderLabel
	order_label.text = order_text
	
	# 服务按钮状态
	var serve_btn: Button = $GuestDetailPanel/ServeButton
	serve_btn.disabled = not has_order

func hide_guest_detail() -> void:
	guest_detail_panel.visible = false
	current_guest_id = -1

func show_card_selection(cards: Array) -> void:
	card_panel.visible = true
	# 面板弹出动画
	if visual_effects and visual_effects.has_method("animate_panel_popup"):
		visual_effects.animate_panel_popup(card_panel)
	
	# 清除旧的卡牌按钮
	for child in card_panel.get_children():
		if child.name != "CardTitle" and child.name != "CardContainer":
			child.queue_free()
	
	# 创建一个 Container 节点来放置卡牌（PanelContainer 的子节点）
	var card_container: Control = card_panel.get_node_or_null("CardContainer")
	if card_container == null:
		card_container = Control.new()
		card_container.name = "CardContainer"
		card_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_panel.add_child(card_container)
	
	# 创建卡牌按钮
	var card_width: float = 150.0
	var start_x: float = (800.0 - cards.size() * (card_width + 20)) / 2
	if start_x < 10:
		start_x = 10
	
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var card_btn: Button = Button.new()
		card_btn.text = card.get("name", "未知")
		card_btn.custom_minimum_size = Vector2(card_width, 80)
		card_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card_btn.offset_left = start_x + i * (card_width + 20)
		card_btn.offset_top = 120
		card_btn.offset_right = card_btn.offset_left + card_width
		card_btn.offset_bottom = card_btn.offset_top + 80
		
		# 设置卡牌颜色
		match card.get("rarity", "common"):
			"rare":
				card_btn.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0))
			"epic":
				card_btn.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9))
			"legendary":
				card_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
			_:
				card_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		
		card_btn.add_theme_font_size_override("font_size", 14)
		card_btn.pressed.connect(_on_card_button_pressed.bind(i))
		card_container.add_child(card_btn)
		
		# 添加卡牌描述
		var desc_label: Label = Label.new()
		desc_label.text = card.get("description", "")
		desc_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		desc_label.offset_left = start_x + i * (card_width + 20)
		desc_label.offset_top = 205
		desc_label.offset_right = desc_label.offset_left + card_width
		desc_label.offset_bottom = desc_label.offset_top + 60
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_container.add_child(desc_label)

func hide_card_selection() -> void:
	card_panel.visible = false
	# 清除卡牌容器里的按钮
	var card_container: Control = card_panel.get_node_or_null("CardContainer")
	if card_container:
		for child in card_container.get_children():
			child.queue_free()

func set_build_mode(enabled: bool) -> void:
	build_mode = enabled
	# 更新建造按钮的视觉效果
	var cancel_btn: Button = $BuildPanel/CancelBuild
	if cancel_btn:
		cancel_btn.visible = enabled

func _on_card_button_pressed(card_index: int) -> void:
	# Notify tutorial that card was selected
	if tutorial and tutorial.has_method("notify_card_selected"):
		tutorial.notify_card_selected()
	emit_signal("card_selected", card_index)

func _update_visibility() -> void:
	pass

func _on_table_pressed() -> void:
	# 按钮点击动画
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($BuildPanel/Table)
	# Notify tutorial that build mode is being entered
	if tutorial and tutorial.has_method("notify_build_mode_entered"):
		tutorial.notify_build_mode_entered()
	emit_signal("build_requested", "table")

func _on_barrel_pressed() -> void:
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($BuildPanel/Barrel)
	emit_signal("build_requested", "barrel")

func _on_fireplace_pressed() -> void:
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($BuildPanel/Fireplace)
	emit_signal("build_requested", "fireplace")

func _on_kitchen_pressed() -> void:
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($BuildPanel/Kitchen)
	emit_signal("build_requested", "kitchen")

func _on_bedroom_pressed() -> void:
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($BuildPanel/Bedroom)
	emit_signal("build_requested", "bedroom")

func _on_next_day_pressed() -> void:
	# 检查游戏是否已启动（防止标题画面时点击）
	var game_mgr = get_node_or_null("/root/Main/GameManager")
	if game_mgr and not game_mgr.game_started:
		return
	# 按钮点击动画
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($NextDayButton)
	# Notify tutorial
	if tutorial and tutorial.has_method("notify_next_day"):
		tutorial.notify_next_day()
	emit_signal("next_day_requested")

func _on_cancel_build_pressed() -> void:
	# 取消建造模式
	var tavern: Node2D = get_node_or_null("/root/Main")
	if tavern:
		tavern.set_build_mode(false)
	set_build_mode(false)

func _on_serve_button_pressed() -> void:
	if current_guest_id != -1:
		# Notify tutorial that guest is being served
		if tutorial and tutorial.has_method("notify_guest_served"):
			tutorial.notify_guest_served()
		emit_signal("guest_selected", current_guest_id)

func _on_close_guest_detail_pressed() -> void:
	hide_guest_detail()

func _on_save_button_pressed() -> void:
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($BuildPanel/SaveButton)
	emit_signal("save_requested")

func _on_load_button_pressed() -> void:
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($BuildPanel/LoadButton)
	emit_signal("load_requested")

func _on_achievement_button_pressed() -> void:
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($BuildPanel/AchievementButton)
	# 显示成就面板
	var achievement_manager: Node = get_node_or_null("/root/Main/AchievementManager")
	if achievement_manager and achievement_manager.has_method("show_achievement_panel"):
		achievement_manager.show_achievement_panel()

func _on_staff_button_pressed() -> void:
	# 检查游戏是否已启动（防止标题画面时点击）
	var game_mgr = get_node_or_null("/root/Main/GameManager")
	if game_mgr and not game_mgr.game_started:
		return
	if visual_effects and visual_effects.has_method("animate_button"):
		visual_effects.animate_button($BuildPanel/StaffButton)
	# 显示员工面板
	var staff_manager: Node = get_node_or_null("/root/Main/StaffManager")
	if staff_manager and staff_manager.has_method("create_staff_panel"):
		var panel: Control = staff_manager.create_staff_panel()
		# 添加到当前场景根节点
		get_tree().root.add_child(panel)
