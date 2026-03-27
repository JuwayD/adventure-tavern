extends Node

## 成就系统 - 追踪玩家成就和统计

signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal stat_updated(stat_name: String, new_value: int)

# 成就定义
const ACHIEVEMENTS: Array = [
	# 开业成就
	{
		"id": "first_guest",
		"name": "第一位客人",
		"description": "服务了第一位客人",
		"icon": "👤",
		"category": "milestone",
		"condition": {"type": "stat", "stat": "guests_served_total", "value": 1}
	},
	{
		"id": "ten_guests",
		"name": "小有名气",
		"description": "服务了10位客人",
		"icon": "⭐",
		"category": "milestone",
		"condition": {"type": "stat", "stat": "guests_served_total", "value": 10}
	},
	{
		"id": "fifty_guests",
		"name": "声名远扬",
		"description": "服务了50位客人",
		"icon": "🌟",
		"category": "milestone",
		"condition": {"type": "stat", "stat": "guests_served_total", "value": 50}
	},
	{
		"id": "hundred_guests",
		"name": "传奇酒馆老板",
		"description": "服务了100位客人",
		"icon": "🏆",
		"category": "milestone",
		"condition": {"type": "stat", "stat": "guests_served_total", "value": 100}
	},
	# 金币成就
	{
		"id": "first_100_gold",
		"name": "初具规模",
		"description": "累计获得100金币",
		"icon": "💰",
		"category": "wealth",
		"condition": {"type": "stat", "stat": "gold_earned_total", "value": 100}
	},
	{
		"id": "first_500_gold",
		"name": "财源滚滚",
		"description": "累计获得500金币",
		"icon": "💎",
		"category": "wealth",
		"condition": {"type": "stat", "stat": "gold_earned_total", "value": 500}
	},
	{
		"id": "first_1000_gold",
		"name": "富甲一方",
		"description": "累计获得1000金币",
		"icon": "👑",
		"category": "wealth",
		"condition": {"type": "stat", "stat": "gold_earned_total", "value": 1000}
	},
	{
		"id": "first_5000_gold",
		"name": "商业巨头",
		"description": "累计获得5000金币",
		"icon": "🏰",
		"category": "wealth",
		"condition": {"type": "stat", "stat": "gold_earned_total", "value": 5000}
	},
	# 声誉成就
	{
		"id": "reputation_50",
		"name": "口碑初立",
		"description": "声誉达到50",
		"icon": "📢",
		"category": "reputation",
		"condition": {"type": "stat", "stat": "reputation_max", "value": 50}
	},
	{
		"id": "reputation_80",
		"name": "远近闻名",
		"description": "声誉达到80",
		"icon": "📣",
		"category": "reputation",
		"condition": {"type": "stat", "stat": "reputation_max", "value": 80}
	},
	{
		"id": "reputation_100",
		"name": "名满天下",
		"description": "声誉达到100",
		"icon": "🎺",
		"category": "reputation",
		"condition": {"type": "stat", "stat": "reputation_max", "value": 100}
	},
	# 设施成就
	{
		"id": "first_table",
		"name": "开始营业",
		"description": "建造了第一张餐桌",
		"icon": "🪑",
		"category": "building",
		"condition": {"type": "stat", "stat": "tables_built", "value": 1}
	},
	{
		"id": "five_tables",
		"name": "座无虚席",
		"description": "建造了5张餐桌",
		"icon": "🍽️",
		"category": "building",
		"condition": {"type": "stat", "stat": "tables_built", "value": 5}
	},
	{
		"id": "first_barrel",
		"name": "酒香四溢",
		"description": "建造了第一个酒桶",
		"icon": "🍺",
		"category": "building",
		"condition": {"type": "stat", "stat": "barrels_built", "value": 1}
	},
	{
		"id": "first_fireplace",
		"name": "温暖如春",
		"description": "建造了第一个壁炉",
		"icon": "🔥",
		"category": "building",
		"condition": {"type": "stat", "stat": "fireplaces_built", "value": 1}
	},
	{
		"id": "first_kitchen",
		"name": "大厨坐镇",
		"description": "建造了第一个厨房",
		"icon": "🍳",
		"category": "building",
		"condition": {"type": "stat", "stat": "kitchens_built", "value": 1}
	},
	{
		"id": "first_guestroom",
		"name": "宾至如归",
		"description": "建造了第一间客房",
		"icon": "🛏️",
		"category": "building",
		"condition": {"type": "stat", "stat": "guestrooms_built", "value": 1}
	},
	# 存活成就
	{
		"id": "survive_7_days",
		"name": "一周年生",
		"description": "成功经营7天",
		"icon": "📅",
		"category": "survival",
		"condition": {"type": "stat", "stat": "days_survived", "value": 7}
	},
	{
		"id": "survive_30_days",
		"name": "月度优秀",
		"description": "成功经营30天",
		"icon": "🗓️",
		"category": "survival",
		"condition": {"type": "stat", "stat": "days_survived", "value": 30}
	},
	# 特殊成就
	{
		"id": "card_collector",
		"name": "卡牌收藏家",
		"description": "选择了10张卡牌",
		"icon": "🃏",
		"category": "special",
		"condition": {"type": "stat", "stat": "cards_selected", "value": 10}
	},
	{
		"id": "no_fuel_survival",
		"name": "意志坚定",
		"description": "在燃料耗尽前坚持到最后",
		"icon": "🕯️",
		"category": "special",
		"condition": {"type": "flag", "flag": "survived_low_fuel"}
	},
	{
		"id": "event_survivor",
		"name": "化险为夷",
		"description": "平安度过10次坏事件",
		"icon": "🍀",
		"category": "special",
		"condition": {"type": "stat", "stat": "bad_events_survived", "value": 10}
	},
	# 员工成就
	{
		"id": "first_staff",
		"name": "招兵买马",
		"description": "雇佣了第一位员工",
		"icon": "👥",
		"category": "staff",
		"condition": {"type": "stat", "stat": "staff_hired_total", "value": 1}
	},
	{
		"id": "full_team",
		"name": "团队齐全",
		"description": "雇佣了所有类型的员工各一名",
		"icon": "🎭",
		"category": "staff",
		"condition": {"type": "stat", "stat": "staff_hired_total", "value": 3}
	}
]

# 玩家统计
var stats: Dictionary = {
	"guests_served_total": 0,
	"gold_earned_total": 0,
	"reputation_max": 0,
	"tables_built": 0,
	"barrels_built": 0,
	"fireplaces_built": 0,
	"kitchens_built": 0,
	"guestrooms_built": 0,
	"days_survived": 0,
	"cards_selected": 0,
	"bad_events_survived": 0,
	"good_events_triggered": 0,
	"staff_hired_total": 0
}

# 已解锁的成就
var unlocked_achievements: Array = []

# 标记（用于特殊条件）
var flags: Dictionary = {}

# UI引用
var achievement_panel: Control = null
var achievement_list: VBoxContainer = null

func _ready() -> void:
	print("[Achievement] Achievement system initialized with ", ACHIEVEMENTS.size(), " achievements")

func initialize_ui(ui_layer: CanvasLayer) -> void:
	"""初始化成就面板UI"""
	if not ui_layer:
		return
	
	# 查找或创建成就面板
	achievement_panel = ui_layer.get_node_or_null("AchievementPanel")
	if not achievement_panel:
		_create_achievement_panel(ui_layer)
	
	_update_achievement_display()

func _create_achievement_panel(ui_layer: CanvasLayer) -> void:
	"""创建成就面板"""
	achievement_panel = PanelContainer.new()
	achievement_panel.name = "AchievementPanel"
	achievement_panel.visible = false
	achievement_panel.set_anchors_preset(Control.PRESET_CENTER)
	achievement_panel.custom_minimum_size = Vector2(400, 500)
	
	var bg_panel: Panel = Panel.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	achievement_panel.add_child(bg_panel)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	bg_panel.add_child(margin)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)
	
	# 标题
	var title: Label = Label.new()
	title.text = "🏆 成就"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# 统计信息
	var stats_label: Label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.text = _get_stats_text()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(stats_label)
	
	var separator: HSeparator = HSeparator.new()
	vbox.add_child(separator)
	
	# 成就列表
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	vbox.add_child(scroll)
	
	achievement_list = VBoxContainer.new()
	achievement_list.name = "AchievementList"
	scroll.add_child(achievement_list)
	
	# 关闭按钮
	var close_btn: Button = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_on_close_achievement_panel)
	vbox.add_child(close_btn)
	
	ui_layer.add_child(achievement_panel)
	print("[Achievement] Created achievement panel")

func _on_close_achievement_panel() -> void:
	if achievement_panel:
		achievement_panel.visible = false

func _get_stats_text() -> String:
	return """📊 本局统计:
• 服务客人数: %d
• 累计获得金币: %d
• 最高声誉: %d
• 存活天数: %d
• 已选卡牌: %d
• 已雇佣员工: %d""" % [
		stats.get("guests_served_total", 0),
		stats.get("gold_earned_total", 0),
		stats.get("reputation_max", 0),
		stats.get("days_survived", 0),
		stats.get("cards_selected", 0),
		stats.get("staff_hired_total", 0)
	]

func _update_achievement_display() -> void:
	"""更新成就列表显示"""
	if not achievement_list:
		return
	
	for child in achievement_list.get_children():
		child.queue_free()
	
	for ach in ACHIEVEMENTS:
		var is_unlocked: bool = ach["id"] in unlocked_achievements
		var item: HBoxContainer = HBoxContainer.new()
		
		var icon_label: Label = Label.new()
		icon_label.text = ach.get("icon", "🎯")
		icon_label.custom_minimum_size = Vector2(40, 30)
		item.add_child(icon_label)
		
		var info_vbox: VBoxContainer = VBoxContainer.new()
		
		var name_label: Label = Label.new()
		name_label.text = ach.get("name", "未知成就")
		if not is_unlocked:
			name_label.modulate = Color(0.5, 0.5, 0.5)
		info_vbox.add_child(name_label)
		
		var desc_label: Label = Label.new()
		desc_label.text = ach.get("description", "")
		desc_label.add_theme_font_size_override("font_size", 12)
		if not is_unlocked:
			desc_label.modulate = Color(0.4, 0.4, 0.4)
		info_vbox.add_child(desc_label)
		
		item.add_child(info_vbox)
		
		if is_unlocked:
			var check: Label = Label.new()
			check.text = "✓"
			check.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
			item.add_child(check)
		
		achievement_list.add_child(item)

func update_stat(stat_name: String, value: int) -> void:
	"""更新统计值并检查成就"""
	if not stats.has(stat_name):
		stats[stat_name] = 0
	
	var old_value: int = stats[stat_name]
	stats[stat_name] = maxi(stats[stat_name], value)
	
	# 更新最大值统计
	if stat_name == "reputation" and value > old_value:
		stats["reputation_max"] = maxi(stats["reputation_max"], value)
	
	emit_signal("stat_updated", stat_name, value)
	
	# 检查相关成就
	_check_achievements_for_stat(stat_name, value)
	
	# 更新UI统计显示
	if achievement_panel and achievement_panel.visible:
		var stats_label: Label = achievement_panel.get_node_or_null("Margin/VBox/StatsLabel")
		if stats_label:
			stats_label.text = _get_stats_text()
	
	print("[Achievement] Stat updated: %s = %d" % [stat_name, value])

func set_flag(flag_name: String, value: bool = true) -> void:
	"""设置标记并检查相关成就"""
	flags[flag_name] = value
	_check_achievements_for_flag(flag_name)
	print("[Achievement] Flag set: %s = %s" % [flag_name, str(value)])

func increment_stat(stat_name: String, amount: int = 1) -> void:
	"""增加统计值"""
	if stats.has(stat_name):
		update_stat(stat_name, stats[stat_name] + amount)
	else:
		update_stat(stat_name, amount)

func _check_achievements_for_stat(stat_name: String, value: int) -> void:
	"""检查与特定统计相关的成就"""
	for ach in ACHIEVEMENTS:
		if ach["id"] in unlocked_achievements:
			continue
		
		var condition: Dictionary = ach.get("condition", {})
		if condition.get("type", "") != "stat":
			continue
		
		if condition.get("stat", "") == stat_name:
			if value >= condition.get("value", 0):
				_unlock_achievement(ach)

func _check_achievements_for_flag(flag_name: String) -> void:
	"""检查与特定标记相关的成就"""
	for ach in ACHIEVEMENTS:
		if ach["id"] in unlocked_achievements:
			continue
		
		var condition: Dictionary = ach.get("condition", {})
		if condition.get("type", "") != "flag":
			continue
		
		if condition.get("flag", "") == flag_name and flags.get(flag_name, false):
			_unlock_achievement(ach)

func _unlock_achievement(achievement: Dictionary) -> void:
	"""解锁成就"""
	var ach_id: String = achievement.get("id", "")
	if ach_id in unlocked_achievements:
		return
	
	unlocked_achievements.append(ach_id)
	emit_signal("achievement_unlocked", ach_id, achievement.get("name", ""))
	
	_update_achievement_display()
	
	print("[Achievement] 🏆 成就解锁: %s - %s" % [ach_id, achievement.get("name", "")])

func show_achievement_panel() -> void:
	"""显示成就面板"""
	if achievement_panel:
		# 更新统计文本
		var stats_label: Label = achievement_panel.get_node_or_null("Margin/VBox/StatsLabel")
		if stats_label:
			stats_label.text = _get_stats_text()
		_update_achievement_display()
		achievement_panel.visible = true

func get_unlocked_count() -> int:
	return unlocked_achievements.size()

func get_total_count() -> int:
	return ACHIEVEMENTS.size()

func get_save_data() -> Dictionary:
	"""获取存档数据"""
	return {
		"unlocked_achievements": unlocked_achievements,
		"stats": stats.duplicate(true),
		"flags": flags.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	"""加载存档数据"""
	if data.has("unlocked_achievements"):
		unlocked_achievements = data["unlocked_achievements"]
	if data.has("stats"):
		stats = data["stats"]
	if data.has("flags"):
		flags = data["flags"]
	
	_update_achievement_display()
	print("[Achievement] Loaded %d achievements and stats" % unlocked_achievements.size())

func reset_progress() -> void:
	"""重置所有进度（用于新游戏）"""
	unlocked_achievements.clear()
	stats.clear()
	flags.clear()
	_update_achievement_display()
	print("[Achievement] Progress reset")
