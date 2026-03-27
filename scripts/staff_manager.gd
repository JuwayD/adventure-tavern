extends Node

## 员工管理系统 - 冒险者酒馆

signal staff_hired(staff_data: Dictionary)
signal staff_fired(staff_id: int)
signal staff_list_changed()

# 员工类型定义
const STAFF_TYPES: Dictionary = {
	"chef": {
		"id": "chef",
		"name": "厨师",
		"icon": "👨‍🍳",
		"hire_cost": 50,
		"daily_cost": 5,
		"description": "厨房产出+50%，食材消耗-20%",
		"effect": "kitchen_boost"
	},
	"waiter": {
		"id": "waiter",
		"name": "服务员",
		"icon": "🧑‍🍳",
		"hire_cost": 40,
		"daily_cost": 3,
		"description": "每日声誉+1，客人满意度+10%",
		"effect": "reputation_boost"
	},
	"bartender": {
		"id": "bartender",
		"name": "调酒师",
		"icon": "🍸",
		"hire_cost": 45,
		"daily_cost": 4,
		"description": "酒水收入+50%，吸引更多商人",
		"effect": "drink_boost"
	}
}

# 员工名字池
const NAMES: Array = [
	"老王", "小李", "阿福", "铁柱", "翠花", "阿强", "小红", "阿明",
	"胖婶", "瘦猴", "大厨", "二丫", "三毛", "四喜", "五福", "六顺"
]

var hired_staff: Array = []  # 已雇佣员工列表
var next_staff_id: int = 1

# 存档数据键名
const SAVE_KEY: String = "staff_data"

func _ready() -> void:
	print("[Staff] Staff manager initialized")

func hire_staff(staff_type: String) -> Dictionary:
	"""雇佣一个员工"""
	if not STAFF_TYPES.has(staff_type):
		return {"success": false, "message": "无效的员工类型"}
	
	var staff_def: Dictionary = STAFF_TYPES[staff_type]
	
	var staff: Dictionary = {
		"id": next_staff_id,
		"type": staff_type,
		"name": NAMES[randi() % NAMES.size()],
		"hire_day": 0,
		"performance": 100  # 绩效 0-100
	}
	next_staff_id += 1
	
	hired_staff.append(staff)
	emit_signal("staff_hired", staff)
	emit_signal("staff_list_changed")
	
	# 更新成就统计
	var achievements: Node = get_node_or_null("/root/Main/AchievementManager")
	if achievements and achievements.has_method("increment_stat"):
		achievements.increment_stat("staff_hired_total")
	
	print("[Staff] Hired: %s (%s)" % [staff["name"], staff_type])
	return {"success": true, "staff": staff}

func fire_staff(staff_id: int) -> bool:
	"""解雇一个员工"""
	for i in range(hired_staff.size()):
		if hired_staff[i]["id"] == staff_id:
			var staff: Dictionary = hired_staff[i]
			hired_staff.remove_at(i)
			emit_signal("staff_fired", staff_id)
			emit_signal("staff_list_changed")
			print("[Staff] Fired: %s (ID: %d)" % [staff["name"], staff_id])
			return true
	return false

func get_staff_count() -> int:
	return hired_staff.size()

func get_staff_count_by_type(staff_type: String) -> int:
	var count: int = 0
	for staff in hired_staff:
		if staff["type"] == staff_type:
			count += 1
	return count

func get_daily_upkeep() -> int:
	"""计算每日员工维护费"""
	var total: int = 0
	for staff in hired_staff:
		if STAFF_TYPES.has(staff["type"]):
			total += STAFF_TYPES[staff["type"]]["daily_cost"]
	return total

func apply_daily_effects(tavern_floor_ref: Node) -> void:
	"""每天应用员工效果"""
	for staff in hired_staff:
		match staff["type"]:
			"waiter":
				# 服务员：每日声誉+1
				tavern_floor_ref.reputation = mini(100, tavern_floor_ref.reputation + 1)
				print("[Staff] %s 的服务为酒馆赢得了声誉+1" % staff["name"])

func get_kitchen_boost_mult() -> float:
	"""厨房产出加成倍率"""
	var chef_count: int = get_staff_count_by_type("chef")
	if chef_count == 0:
		return 1.0
	return 1.0 + (chef_count * 0.5)  # 每个厨师+50%

func get_drink_boost_mult() -> float:
	"""酒水收入加成倍率"""
	var bartender_count: int = get_staff_count_by_type("bartender")
	if bartender_count == 0:
		return 1.0
	return 1.0 + (bartender_count * 0.5)  # 每个调酒师+50%

func get_ingredient_cost_mult() -> float:
	"""食材消耗倍率（越低越好）"""
	var chef_count: int = get_staff_count_by_type("chef")
	if chef_count == 0:
		return 1.0
	return max(0.5, 1.0 - (chef_count * 0.2))  # 每个厨师-20%，最低50%

func get_guest_satisfaction_boost() -> float:
	"""客人满意度加成（用于小费和声誉）"""
	var waiter_count: int = get_staff_count_by_type("waiter")
	if waiter_count == 0:
		return 0.0
	return waiter_count * 0.1  # 每个服务员+10%

func process_daily_upkeep(tavern_floor_ref: Node) -> int:
	"""扣除每日维护费，返回扣除金额"""
	var upkeep: int = get_daily_upkeep()
	if upkeep > 0:
		tavern_floor_ref.gold -= upkeep
		print("[Staff] 员工维护费: -%d 金币" % upkeep)
	return upkeep

# ===== UI 面板 =====

func create_staff_panel() -> Control:
	"""创建员工管理面板"""
	var panel: Panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(400, 360)
	panel.title = "员工管理"
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.6, 0.4, 0.2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	# 标题
	var title: Label = Label.new()
	title.text = "员工管理"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0, 10)
	title.size = Vector2(400, 30)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	panel.add_child(title)
	
	# 关闭按钮
	var close_btn: Button = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(360, 10)
	close_btn.size = Vector2(30, 30)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_on_close_staff_panel.bind(panel))
	panel.add_child(close_btn)
	
	# 员工列表区域
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(15)  # Control.PRESET_WIDE
	scroll.position = Vector2(10, 50)
	scroll.size = Vector2(380, 140)
	panel.add_child(scroll)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size = Vector2(360, 130)
	scroll.add_child(vbox)
	
	# 显示已雇佣员工
	if hired_staff.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "尚未雇佣任何员工"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(empty_lbl)
	else:
		for staff in hired_staff:
			var staff_lbl: Label = Label.new()
			var staff_def: Dictionary = STAFF_TYPES.get(staff["type"], {})
			staff_lbl.text = "%s %s (%s) - 每日%dg" % [
				staff_def.get("icon", "?"),
				staff["name"],
				staff_def.get("name", "?"),
				staff_def.get("daily_cost", 0)
			]
			staff_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
			vbox.add_child(staff_lbl)
	
	# 雇佣标题
	var hire_lbl: Label = Label.new()
	hire_lbl.text = "雇佣员工"
	hire_lbl.position = Vector2(10, 200)
	hire_lbl.size = Vector2(380, 25)
	hire_lbl.add_theme_font_size_override("font_size", 16)
	hire_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	panel.add_child(hire_lbl)
	
	# 雇佣按钮
	var btn_y: float = 225
	for staff_type in STAFF_TYPES.keys():
		var staff_def: Dictionary = STAFF_TYPES[staff_type]
		var btn: Button = Button.new()
		btn.text = "%s %s - %dg (每日%dg)" % [
			staff_def["icon"],
			staff_def["name"],
			staff_def["hire_cost"],
			staff_def["daily_cost"]
		]
		btn.position = Vector2(10, btn_y)
		btn.size = Vector2(380, 35)
		btn.pressed.connect(_on_hire_staff.bind(staff_type, panel))
		panel.add_child(btn)
		
		# 说明
		var desc_lbl: Label = Label.new()
		desc_lbl.text = staff_def["description"]
		desc_lbl.position = Vector2(20, btn_y + 35)
		desc_lbl.size = Vector2(370, 20)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		panel.add_child(desc_lbl)
		
		btn_y += 55
	
	# 每日维护费显示
	var upkeep_lbl: Label = Label.new()
	upkeep_lbl.text = "每日维护费: %dg" % get_daily_upkeep()
	upkeep_lbl.position = Vector2(10, btn_y + 5)
	upkeep_lbl.size = Vector2(380, 20)
	upkeep_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	panel.add_child(upkeep_lbl)
	
	return panel

func _on_close_staff_panel(panel: Control) -> void:
	panel.get_parent().remove_child(panel)
	panel.queue_free()

func _on_hire_staff(staff_type: String, panel: Control) -> void:
	var tavern: Node = get_node_or_null("/root/Main/TavernFloor")
	if tavern == null:
		return
	
	var staff_def: Dictionary = STAFF_TYPES[staff_type]
	var hire_cost: int = staff_def["hire_cost"]
	
	if tavern.gold < hire_cost:
		# 金币不足，显示提示
		_show_message(panel, "金币不足! 需要 %d 金币" % hire_cost)
		return
	
	# 扣除雇佣费
	tavern.gold -= hire_cost
	tavern.emit_signal("resource_changed", "gold", tavern.gold, tavern.gold + hire_cost)
	
	# 雇佣员工
	var result: Dictionary = hire_staff(staff_type)
	if result["success"]:
		_show_message(panel, "成功雇佣: %s!" % staff_def["name"])
		# 刷新面板
		var parent: Node = panel.get_parent()
		parent.remove_child(panel)
		panel.queue_free()
		var new_panel: Control = create_staff_panel()
		parent.add_child(new_panel)

func _show_message(panel: Control, msg: String) -> void:
	# 在面板上显示临时消息
	var msg_lbl: Label = Label.new()
	msg_lbl.text = msg
	msg_lbl.set_anchors_preset(Control.PRESET_CENTER)
	msg_lbl.position = Vector2(0, 160)
	msg_lbl.size = Vector2(400, 30)
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	msg_lbl.z_index = 100
	panel.add_child(msg_lbl)
	
	# 2秒后移除
	await get_tree().create_timer(2.0).timeout
	if msg_lbl.get_parent() != null:
		msg_lbl.get_parent().remove_child(msg_lbl)
		msg_lbl.queue_free()

# ===== 存档/读档 =====

func get_save_data() -> Dictionary:
	"""获取存档数据"""
	return {
		"hired_staff": hired_staff,
		"next_staff_id": next_staff_id
	}

func load_save_data(data: Dictionary) -> void:
	"""加载存档数据"""
	hired_staff = data.get("hired_staff", [])
	next_staff_id = int(data.get("next_staff_id", 1))
	emit_signal("staff_list_changed")
	print("[Staff] Loaded %d staff members" % hired_staff.size())

func reset_progress() -> void:
	"""新游戏时重置"""
	hired_staff.clear()
	next_staff_id = 1
	emit_signal("staff_list_changed")
	print("[Staff] Staff progress reset")
