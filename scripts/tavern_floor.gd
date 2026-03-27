extends Node2D

## 酒馆场景 - 核心游戏场景

signal resource_changed(resource_name: String, new_value: int, old_value: int)
signal day_changed(day_number: int)
signal guest_arrived(guest_id: int)
signal guest_left(guest_id: int)
signal event_triggered(event_type: String, event_data: Dictionary)
signal roguelike_card_requested(cards: Array)
signal guest_clicked(guest_id: int)
signal build_mode_changed(in_build_mode: bool, facility_type: String)

const GRID_SIZE: int = 64
const GRID_COLS: int = 10
const GRID_ROWS: int = 8

# 资源
var gold: int = 100
var reputation: int = 50
var ingredients: int = 20
var fuel: int = 10

# 游戏状态
var current_day: int = 1
var guests_served_today: int = 0
var income_today: int = 0
var day_phase: int = 0
var legendary_boost_days: int = 0
var golden_age_days: int = 0
var kitchen_upgrade_days: int = 0

# 客人队列
var guest_queue: Array = []
var active_guests: Array = []

# 酒馆设施网格
var facility_grid: Array = []
var facility_types: Dictionary = {}

# 建造模式
var build_mode: bool = false
var selected_facility: String = ""
var hovered_cell: Vector2i = Vector2i(-1, -1)

# Tutorial reference
var tutorial: Node = null

# Visual effects reference
var visual_effects: Node = null

# 肉鸽卡牌定义
const ROGUELIKE_CARDS: Array = [
	# Common - 资源获取
	{
		"id": "gold_rush",
		"name": "金币冲刺",
		"type": "resource_boost",
		"rarity": "common",
		"description": "立即获得25金币",
		"gold": 25
	},
	{
		"id": "food_supply",
		"name": "食材补给",
		"type": "resource_boost",
		"rarity": "common",
		"description": "获得12食材",
		"ingredients": 12
	},
	{
		"id": "warm_fire",
		"name": "温暖火焰",
		"type": "resource_boost",
		"rarity": "common",
		"description": "获得6燃料",
		"fuel": 6
	},
	{
		"id": "reputation_boost",
		"name": "口碑宣传",
		"type": "resource_boost",
		"rarity": "common",
		"description": "声誉+8",
		"reputation": 8
	},
	# Rare - 特殊事件
	{
		"id": "mysterious_merchant",
		"name": "神秘商人",
		"type": "special",
		"rarity": "rare",
		"description": "商人送你40金币作为见面礼"
	},
	{
		"id": "adventurer_guild",
		"name": "冒险者公会",
		"type": "special",
		"rarity": "rare",
		"description": "公会推荐更多冒险者光顾"
	},
	{
		"id": "noble_recommendation",
		"name": "贵族推荐",
		"type": "special",
		"rarity": "rare",
		"description": "贵族为你引流，声誉+15"
	},
	# Epic - 设施/收入加成
	{
		"id": "kitchen_upgrade",
		"name": "厨房升级",
		"type": "facility_boost",
		"rarity": "epic",
		"description": "厨房产出+100%，持续3天"
	},
	{
		"id": "tavern_charm",
		"name": "酒馆魅力",
		"type": "special",
		"rarity": "epic",
		"description": "今日所有客人小费+50%"
	},
	# Legendary - 强力效果
	{
		"id": "legendary_tavern",
		"name": "传奇酒馆",
		"type": "special",
		"rarity": "legendary",
		"description": "所有收入+50%，持续3天"
	},
	{
		"id": "golden_age",
		"name": "黄金时代",
		"type": "special",
		"rarity": "legendary",
		"description": "接下来2天无需消耗燃料和食材!"
	}
]

# 设施定义
const FACILITY_COSTS: Dictionary = {
	"table": 20,
	"barrel": 30,
	"fireplace": 50,
	"kitchen": 100,
	"bedroom": 80
}

const FACILITY_INCOME: Dictionary = {
	"table": 5,
	"barrel": 3,
	"fireplace": 2,
	"kitchen": 8,
	"bedroom": 10
}

func _ready() -> void:
	tutorial = get_node_or_null("/root/Main/TutorialManager")
	visual_effects = get_node_or_null("/root/Main/VisualEffects")
	_initialize_grid()
	_update_ui()

func _initialize_grid() -> void:
	facility_grid = []
	for i in range(GRID_COLS * GRID_ROWS):
		facility_grid.append(false)
	_facility_place(4, 3, "barrel")
	_facility_place(5, 3, "barrel")
	_facility_place(3, 5, "table")
	_facility_place(6, 5, "table")
	print("[DEBUG] After init - facility_types: ", facility_types)
	print("[DEBUG] Keys type: ", typeof(facility_types.keys()[0]) if facility_types.size() > 0 else "empty")

func _facility_place(col: int, row: int, facility_type: String) -> bool:
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return false
	var idx: int = row * GRID_COLS + col
	if facility_grid[idx]:
		return false
	facility_grid[idx] = true
	facility_types[idx] = facility_type
	return true

func _facility_remove(col: int, row: int) -> bool:
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return false
	var idx: int = row * GRID_COLS + col
	if not facility_grid[idx]:
		return false
	facility_grid[idx] = false
	facility_types.erase(idx)
	return true

func build_facility(col: int, row: int, facility_type: String) -> bool:
	if not FACILITY_COSTS.has(facility_type):
		return false
	var cost: int = FACILITY_COSTS[facility_type]
	if gold < cost:
		return false
	if not _facility_place(col, row, facility_type):
		return false
	gold -= cost
	_update_ui()
	emit_signal("resource_changed", "gold", gold, gold + cost)
	
	# 播放建造音效
	var audio: Node = get_node_or_null("/root/Main/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("build")
	
	# 播放建造粒子效果
	if visual_effects and visual_effects.has_method("play_particle"):
		var cell_pos: Vector2 = Vector2(col * GRID_SIZE + GRID_OFFSET_X + GRID_SIZE/2, row * GRID_SIZE + GRID_OFFSET_Y + GRID_SIZE/2)
		visual_effects.play_particle("build_complete", cell_pos, self)
	
	# 显示资源变化浮动文字
	if visual_effects and visual_effects.has_method("show_resource_change"):
		var cell_pos: Vector2 = Vector2(col * GRID_SIZE + GRID_OFFSET_X + GRID_SIZE/2, row * GRID_SIZE + GRID_OFFSET_Y)
		visual_effects.show_resource_change("gold", -cost, cell_pos, self)
	
	# Notify tutorial that facility was placed
	if tutorial and tutorial.has_method("notify_facility_placed"):
		tutorial.notify_facility_placed()
	
	# 更新设施建造成就
	var achievements: Node = get_node_or_null("/root/Main/AchievementManager")
	if achievements and achievements.has_method("increment_stat"):
		match facility_type:
			"table":
				achievements.increment_stat("tables_built")
			"barrel":
				achievements.increment_stat("barrels_built")
			"fireplace":
				achievements.increment_stat("fireplaces_built")
			"kitchen":
				achievements.increment_stat("kitchens_built")
			"bedroom":
				achievements.increment_stat("guestrooms_built")
	
	return true

func remove_facility(col: int, row: int) -> bool:
	var idx: int = row * GRID_COLS + col
	if not facility_grid[idx]:
		return false
	var facility_type: String = facility_types[idx]
	var refund: int = int(FACILITY_COSTS[facility_type] * 0.5)
	_facility_remove(col, row)
	gold += refund
	_update_ui()
	emit_signal("resource_changed", "gold", gold, gold - refund)
	return true

func set_build_mode(enabled: bool, facility_type: String = "") -> void:
	build_mode = enabled
	selected_facility = facility_type if enabled else ""
	emit_signal("build_mode_changed", build_mode, selected_facility)

func get_build_mode() -> bool:
	return build_mode

func get_selected_facility() -> String:
	return selected_facility

func can_build_at(col: int, row: int) -> bool:
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return false
	var idx: int = row * GRID_COLS + col
	if facility_grid[idx]:
		return false
	# 检查是否相邻现有设施
	var neighbors: Array = [
		idx - 1 if col > 0 else -1,
		idx + 1 if col < GRID_COLS - 1 else -1,
		idx - GRID_COLS if row > 0 else -1,
		idx + GRID_COLS if row < GRID_ROWS - 1 else -1
	]
	for n in neighbors:
		if n >= 0 and n < facility_grid.size() and facility_grid[n]:
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var col: int = int(mouse_pos.x / GRID_SIZE)
		var row: int = int(mouse_pos.y / GRID_SIZE)
		hovered_cell = Vector2i(col, row)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_pos: Vector2 = event.position
			var col: int = int(mouse_pos.x / GRID_SIZE)
			var row: int = int(mouse_pos.y / GRID_SIZE)
			
			if build_mode and selected_facility != "":
				# 建造模式：点击放置设施
				if can_build_at(col, row) and gold >= FACILITY_COSTS.get(selected_facility, 999):
					if build_facility(col, row, selected_facility):
						# 建造成功后保持建造模式，可以继续放置
						pass
				else:
					# 无效位置，退出建造模式
					set_build_mode(false)
			else:
				# 检查是否点击了客人
				_handle_guest_click(mouse_pos)

func _handle_guest_click(mouse_pos: Vector2) -> void:
	for guest in active_guests:
		var guest_pos: Vector2 = guest.get("position", Vector2.ZERO)
		var guest_center: Vector2 = guest_pos + Vector2(GRID_SIZE / 2, GRID_SIZE / 2)
		if mouse_pos.distance_to(guest_center) < 24:
			emit_signal("guest_clicked", guest["id"])
			# Notify tutorial
			if tutorial and tutorial.has_method("notify_guest_clicked"):
				tutorial.notify_guest_clicked()
			return

func _process(_delta: float) -> void:
	queue_redraw()

# 网格偏移 - 避开左上角 UI 面板
const GRID_OFFSET_X: int = 20
const GRID_OFFSET_Y: int = 200

func _draw() -> void:
	# 1. 绘制网格背景（带偏移）
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var cell_pos: Vector2 = Vector2(col * GRID_SIZE + GRID_OFFSET_X, row * GRID_SIZE + GRID_OFFSET_Y)
			var cell_rect: Rect2 = Rect2(cell_pos, Vector2(GRID_SIZE, GRID_SIZE))
			
			var grid_color: Color = Color(0.35, 0.28, 0.2) if (row + col) % 2 == 0 else Color(0.42, 0.33, 0.24)
			draw_rect(cell_rect, grid_color)
			draw_rect(cell_rect, Color(0.2, 0.15, 0.1), false, 2.0)
	
	# 2. 建造模式：显示可放置位置（带偏移）
	if build_mode:
		for row in range(GRID_ROWS):
			for col in range(GRID_COLS):
				if can_build_at(col, row):
					var cell_pos: Vector2 = Vector2(col * GRID_SIZE + GRID_OFFSET_X, row * GRID_SIZE + GRID_OFFSET_Y)
					var cell_rect: Rect2 = Rect2(cell_pos, Vector2(GRID_SIZE, GRID_SIZE))
					if hovered_cell.x == col and hovered_cell.y == row:
						draw_rect(cell_rect, Color(0.3, 0.8, 0.3, 0.5))
					else:
						draw_rect(cell_rect, Color(0.3, 0.6, 0.3, 0.3))
	
	# 3. 绘制设施（带偏移）
	for idx in facility_types:
		var col: int = int(idx) % GRID_COLS
		var row: int = int(int(idx) / GRID_COLS)
		var cell_pos: Vector2 = Vector2(col * GRID_SIZE + GRID_OFFSET_X, row * GRID_SIZE + GRID_OFFSET_Y)
		var facility_type: String = facility_types[idx]
		_draw_facility(cell_pos, facility_type)
	
	# 绘制客人（带偏移）
	for guest in active_guests:
		var guest_pos: Vector2 = guest.get("position", Vector2.ZERO) + Vector2(GRID_OFFSET_X, GRID_OFFSET_Y)
		_draw_guest(guest_pos, guest.get("type", "common"))

func _draw_facility(pos: Vector2, facility_type: String) -> void:
	var rect: Rect2 = Rect2(pos + Vector2(4, 4), Vector2(GRID_SIZE - 8, GRID_SIZE - 8))
	match facility_type:
		"table":
			# 餐桌 - 亮橙色
			draw_rect(rect, Color(0.85, 0.55, 0.25))
			draw_rect(rect, Color(0.5, 0.3, 0.15), false, 3.0)
		"barrel":
			# 酒桶 - 深棕色
			draw_circle(pos + Vector2(GRID_SIZE/2, GRID_SIZE/2), GRID_SIZE/2 - 8, Color(0.65, 0.35, 0.15))
			draw_circle(pos + Vector2(GRID_SIZE/2, GRID_SIZE/2), GRID_SIZE/2 - 12, Color(0.75, 0.4, 0.2))
		"fireplace":
			# 壁炉 - 石灰色
			draw_rect(rect, Color(0.5, 0.45, 0.4))
		"kitchen":
			# 厨房 - 深灰色
			draw_rect(rect, Color(0.4, 0.4, 0.4))
		"bedroom":
			# 客房 - 蓝色
			draw_rect(rect, Color(0.3, 0.4, 0.7))
			draw_rect(rect, Color(0.4, 0.4, 0.45))
			draw_rect(Rect2(pos + Vector2(8, 8), Vector2(20, 20)), Color(0.8, 0.8, 0.8))
		"bedroom":
			draw_rect(rect, Color(0.5, 0.35, 0.25))
			draw_rect(Rect2(pos + Vector2(10, 20), Vector2(44, 20)), Color(0.7, 0.5, 0.35))

func _draw_guest(pos: Vector2, guest_type: String) -> void:
	var color: Color
	match guest_type:
		"common":
			color = Color(0.8, 0.8, 0.7)
		"noble":
			color = Color(0.8, 0.6, 0.9)
		"merchant":
			color = Color(0.7, 0.8, 0.6)
		"adventurer":
			color = Color(0.9, 0.5, 0.5)
		_:
			color = Color(0.8, 0.8, 0.7)
	
	var guest_size: float = 20.0
	var center: Vector2 = pos + Vector2(GRID_SIZE/2, GRID_SIZE/2)
	draw_circle(center, guest_size/2, color)
	# 眼睛
	draw_circle(center + Vector2(-4, -2), 2, Color.BLACK)
	draw_circle(center + Vector2(4, -2), 2, Color.BLACK)

func _update_ui() -> void:
	var ui: CanvasLayer = get_node_or_null("/root/Main/UI")
	if ui:
		ui.update_resources(gold, reputation, ingredients, fuel)
		ui.update_day(current_day)

func spawn_guest() -> Dictionary:
	var guest_types: Array = ["common", "common", "common", "merchant", "adventurer", "noble"]
	var guest_type: String = guest_types[randi() % guest_types.size()]
	
	var empty_cells: Array = []
	for i in range(facility_grid.size()):
		if not facility_grid[i] and _guest_can_sit_at(i):
			empty_cells.append(i)
	
	if empty_cells.is_empty():
		return {}
	
	var cell_idx: int = empty_cells[randi() % empty_cells.size()]
	var col: int = cell_idx % GRID_COLS
	var row: int = cell_idx / GRID_COLS
	
	var guest: Dictionary = {
		"id": Time.get_ticks_msec(),
		"type": guest_type,
		"position": Vector2(col * GRID_SIZE, row * GRID_SIZE),
		"cell_idx": cell_idx,
		"patience": 100,
		"order": _generate_order(guest_type),
		"tip_multiplier": 1.0
	}
	
	active_guests.append(guest)
	emit_signal("guest_arrived", guest["id"])
	return guest

func _guest_can_sit_at(cell_idx: int) -> bool:
	var col: int = cell_idx % GRID_COLS
	var row: int = cell_idx / GRID_COLS
	var neighbors: Array = [
		row * GRID_COLS + (col - 1),
		row * GRID_COLS + (col + 1),
		(row - 1) * GRID_COLS + col,
		(row + 1) * GRID_COLS + col
	]
	for n in neighbors:
		if n >= 0 and n < facility_grid.size() and facility_types.has(n):
			if facility_types[n] == "table" or facility_types[n] == "barrel":
				return true
	return false

func _generate_order(guest_type: String) -> Dictionary:
	var order: Dictionary = {}
	match guest_type:
		"common":
			order = {"food": 1, "drink": 1}
		"merchant":
			order = {"food": 2, "drink": 2}
		"noble":
			order = {"food": 1, "drink": 3, "luxury": 1}
		"adventurer":
			order = {"food": 3, "drink": 1}
		_:
			order = {"food": 1, "drink": 1}
	return order

func get_guest_by_id(guest_id: int) -> Dictionary:
	for guest in active_guests:
		if guest["id"] == guest_id:
			return guest
	return {}

func serve_guest(guest_id: int, resource: String, amount: int) -> bool:
	for guest in active_guests:
		if guest["id"] == guest_id:
			if guest["order"].has(resource) and guest["order"][resource] > 0:
				guest["order"][resource] -= amount
				return true
	return false

func serve_guest_all(guest_id: int) -> Dictionary:
	"""为客人提供服务，自动满足所有订单项"""
	var guest: Dictionary = get_guest_by_id(guest_id)
	if guest.is_empty():
		return {"success": false, "message": "客人不存在"}
	
	var order: Dictionary = guest["order"]
	var items_served: Array = []
	var total_ingredient_cost: int = 0
	var luxury_count: int = 0
	var order_items: int = 0
	
	for item in order:
		var qty: int = int(order[item])
		if qty > 0:
			order_items += qty
			if item == "food":
				if ingredients < qty:
					return {"success": false, "message": "食材不足!"}
				ingredients -= qty
				total_ingredient_cost += qty
				items_served.append("食物 x%d" % qty)
			elif item == "drink":
				if ingredients < qty:
					return {"success": false, "message": "食材不足!"}
				ingredients -= qty
				total_ingredient_cost += qty
				items_served.append("酒水 x%d" % qty)
			elif item == "luxury":
				if reputation < 10:
					return {"success": false, "message": "声誉不足!"}
				reputation -= 5
				luxury_count += 1
				items_served.append("奢侈品 x%d" % qty)
	
	# 清空订单
	guest["order"] = {"food": 0, "drink": 0, "luxury": 0}
	
	_update_ui()
	
	# 记录本次服务的消耗和原始订单（用于结算）
	guest["last_service_cost"] = total_ingredient_cost
	guest["last_luxury_count"] = luxury_count
	# 保存原始订单项数（结算时用，因为 order 已被清空）
	guest["_served_order_items"] = order_items
	
	# 员工效果：厨师减少食材消耗（退还部分食材）
	var staff_mgr: Node = get_node_or_null("/root/Main/StaffManager")
	if staff_mgr and staff_mgr.has_method("get_ingredient_cost_mult"):
		var mult: float = staff_mgr.get_ingredient_cost_mult()
		if mult < 1.0:
			var refund: int = int(total_ingredient_cost * (1.0 - mult))
			if refund > 0:
				ingredients += refund
				_update_ui()
	
	return {
		"success": true,
		"items": items_served,
		"ingredient_cost": total_ingredient_cost,
		"luxury_count": luxury_count,
		"message": "服务完成!"
	}

func checkout_guest(guest_id: int) -> int:
	for i in range(active_guests.size()):
		if active_guests[i]["id"] == guest_id:
			var guest: Dictionary = active_guests[i]
			var payment: int = _calculate_payment(guest)
			var guest_pos: Vector2 = guest.get("position", Vector2.ZERO)
			active_guests.remove_at(i)
			guests_served_today += 1
			income_today += payment
			gold += payment
			# 声誉小幅提升（基础值，不在 checkout 里重复加）
			emit_signal("guest_left", guest_id)
			emit_signal("resource_changed", "gold", gold, gold - payment)
			
			# 播放金币获得效果
			if visual_effects and visual_effects.has_method("play_particle"):
				var screen_pos: Vector2 = guest_pos + Vector2(GRID_OFFSET_X + GRID_SIZE/2, GRID_OFFSET_Y + GRID_SIZE/2)
				visual_effects.play_particle("coin_spark", screen_pos, self)
			
			# 显示金币浮动文字
			if visual_effects and visual_effects.has_method("show_floating_text"):
				var screen_pos: Vector2 = guest_pos + Vector2(GRID_OFFSET_X + GRID_SIZE/2, GRID_OFFSET_Y)
				visual_effects.show_floating_text("+%d💰" % payment, screen_pos, self, Color.GOLD, 24)
			
			return payment
	return 0

func _calculate_payment(guest: Dictionary) -> int:
	# 基础收入 = 订单项数 × 每项基础价
	# 注意：此时 guest["order"] 已被清空，使用保存的 _served_order_items
	var order_items: int = int(guest.get("_served_order_items", 0))
	var luxury_count: int = int(guest.get("last_luxury_count", 0))
	
	# 厨房产出加成 (有厨房时食物收入翻倍, kitchen_upgrade_days 时再翻倍)
	var has_kitchen: bool = facility_types.values().has("kitchen")
	var kitchen_mult: float = 1.0
	if has_kitchen:
		kitchen_mult = 2.0
	if kitchen_upgrade_days > 0:
		kitchen_mult *= 2.0
	
	# 员工加成：厨师额外+50%厨房产出
	var staff_mgr: Node = get_node_or_null("/root/Main/StaffManager")
	if staff_mgr and staff_mgr.has_method("get_kitchen_boost_mult"):
		kitchen_mult *= staff_mgr.get_kitchen_boost_mult()
	
	# 基础收入（食物受厨房产出加成影响）
	var base_income: int = order_items * 8  # 每项订单基础8金
	
	# 客人类型加成
	var type_mult: float = 1.0
	match guest["type"]:
		"noble":
			type_mult = 2.5
		"merchant":
			type_mult = 1.8
		"adventurer":
			type_mult = 1.4
		_:
			type_mult = 1.0
	
	# 员工加成：调酒师提升酒水收入
	if staff_mgr and staff_mgr.has_method("get_drink_boost_mult"):
		# 调酒师加成在酒水部分体现，这里简单乘以平均加成
		type_mult *= staff_mgr.get_drink_boost_mult()
	
	# 订单完成额外奖励
	var completion_bonus: int = 0
	if order_items == 0:  # 订单已清空 = 完成了服务
		completion_bonus = 10
		reputation = mini(100, reputation + 2)
	
	# 设施加成
	var facility_bonus: int = 0
	if facility_types.values().has("bedroom") and guest["type"] == "noble":
		facility_bonus = 15  # 客房吸引贵族额外15金
	
	# 传奇酒馆加成
	var legendary_mult: float = 1.0
	if legendary_boost_days > 0:
		legendary_mult = 1.5
	
	# 员工加成：服务员提升小费
	var satisfaction_boost: float = 0.0
	if staff_mgr and staff_mgr.has_method("get_guest_satisfaction_boost"):
		satisfaction_boost = staff_mgr.get_guest_satisfaction_boost()
	
	var payment: int = int(((base_income * type_mult * kitchen_mult) + completion_bonus + facility_bonus) * legendary_mult)
	# 服务员满意度加成（增加小费）
	payment = int(payment * (1.0 + satisfaction_boost))
	return maxi(1, payment)

func advance_day() -> void:
	# 传奇酒馆加成递减
	if legendary_boost_days > 0:
		legendary_boost_days -= 1
	
	# 厨房升级加成递减
	if kitchen_upgrade_days > 0:
		kitchen_upgrade_days -= 1
	
	current_day += 1
	guests_served_today = 0
	income_today = 0
	day_phase = 0
	
	# 播放日期变化音效
	var audio: Node = get_node_or_null("/root/Main/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("day_change")
	
	# 播放日期变化粒子效果
	if visual_effects and visual_effects.has_method("play_particle"):
		var center_pos: Vector2 = Vector2(GRID_OFFSET_X + GRID_COLS * GRID_SIZE / 2, GRID_OFFSET_Y + GRID_ROWS * GRID_SIZE / 2)
		visual_effects.play_particle("card_select", center_pos, self)
	
	# 消耗资源（日常运营成本）
	# 壁炉减少燃料消耗
	var fireplace_count: int = 0
	for f in facility_types.values():
		if f == "fireplace":
			fireplace_count += 1
	var daily_fuel_cost: int = 3 - fireplace_count  # 每个壁炉-1燃料消耗
	var daily_ingredient_cost: int = 8
	
	# 黄金时代：无需消耗资源
	if golden_age_days > 0:
		daily_fuel_cost = 0
		daily_ingredient_cost = 0
		golden_age_days -= 1
	
	# 员工效果：厨师减少食材消耗
	var staff_mgr: Node = get_node_or_null("/root/Main/StaffManager")
	if staff_mgr and staff_mgr.has_method("get_ingredient_cost_mult"):
		daily_ingredient_cost = int(daily_ingredient_cost * staff_mgr.get_ingredient_cost_mult())
	
	fuel = maxi(0, fuel - daily_fuel_cost)
	ingredients = maxi(0, ingredients - daily_ingredient_cost)
	
	# 设施维护费（每个设施每天1金维护费）
	var facility_maintenance: int = facility_types.size()
	
	# 计算今日设施加成收入（仅作为辅助）
	var table_count: int = 0
	var barrel_count: int = 0
	var kitchen_count: int = 0
	var bedroom_count: int = 0
	for f in facility_types.values():
		if f == "table":
			table_count += 1
		elif f == "barrel":
			barrel_count += 1
		elif f == "kitchen":
			kitchen_count += 1
		elif f == "bedroom":
			bedroom_count += 1
	
	# 设施基础收入（降低）= 服务客人的补充收入
	var facility_bonus: int = table_count * 2 + barrel_count * 1
	# 厨房产出加成已移至 _calculate_payment
	# 客房加成也已移至 _calculate_payment
	
	# 总收入 = 设施加成 - 维护费 - 员工维护费
	income_today = facility_bonus - facility_maintenance
	
	# 员工每日维护费
	if staff_mgr and staff_mgr.has_method("process_daily_upkeep"):
		var staff_upkeep: int = staff_mgr.process_daily_upkeep(self)
		income_today -= staff_upkeep
	
	# 传奇酒馆加成（仅影响设施加成部分）
	if legendary_boost_days > 0:
		income_today = int(income_today * 1.5)
	
	gold += income_today
	
	# 触发随机事件
	_trigger_random_event()
	
	# 员工每日效果（服务员声誉加成）
	staff_mgr = get_node_or_null("/root/Main/StaffManager")
	if staff_mgr and staff_mgr.has_method("apply_daily_effects"):
		staff_mgr.apply_daily_effects(self)
	
	# 清空当前客人
	for guest in active_guests:
		emit_signal("guest_left", guest["id"])
	active_guests.clear()
	
	# 生成新客人
	for i in range(3 + randi() % 3):
		await get_tree().create_timer(0.5).timeout
		spawn_guest()
	
	_update_ui()
	emit_signal("day_changed", current_day)
	
	# 触发肉鸽卡牌选择 (每天有一次选择机会)
	await get_tree().create_timer(1.0).timeout
	_trigger_roguelike_card()

func _trigger_roguelike_card() -> void:
	# 随机选择3张卡牌
	var cards: Array = []
	var available: Array = ROGUELIKE_CARDS.duplicate()
	available.shuffle()
	
	for i in range(mini(3, available.size())):
		cards.append(available[i])
	
	if cards.size() > 0:
		emit_signal("roguelike_card_requested", cards)

func _trigger_random_event() -> void:
	var roll: int = randi() % 100
	var event_type: String = ""
	var event_data: Dictionary = {}
	
	if roll < 30:
		event_type = "good"
		var good_events: Array = [
			{"msg": "旅人带来惊喜小费!", "gold": 10 + randi() % 20},
			{"msg": "商人出售新鲜食材", "ingredients": 5 + randi() % 10},
			{"msg": "运气好！燃料自发火了", "fuel": 2 + randi() % 5}
		]
		event_data = good_events[randi() % good_events.size()]
		gold += int(event_data.get("gold", 0))
		ingredients += int(event_data.get("ingredients", 0))
		fuel += int(event_data.get("fuel", 0))
	elif roll < 60:
		event_type = "bad"
		var bad_events: Array = [
			{"msg": "醉汉打翻了酒杯!", "reputation": -5},
			{"msg": "厨房着火! 损失食材", "ingredients": -5},
			{"msg": "骗子付了假币!", "gold": -10}
		]
		event_data = bad_events[randi() % bad_events.size()]
		reputation = maxi(0, reputation + int(event_data.get("reputation", 0)))
		ingredients = maxi(0, ingredients + int(event_data.get("ingredients", 0)))
		gold = maxi(0, gold + int(event_data.get("gold", 0)))
	else:
		event_type = "none"
		event_data = {"msg": "平静的一天"}
	
	_update_ui()
	emit_signal("event_triggered", event_type, event_data)

func is_game_over() -> bool:
	return gold < 0 or reputation <= 0 or fuel <= 0

func get_grid_info() -> Dictionary:
	return {
		"grid_size": GRID_SIZE,
		"grid_cols": GRID_COLS,
		"grid_rows": GRID_ROWS,
		"facility_grid": facility_grid,
		"facility_types": facility_types
	}

# ===== 存档/读档系统 =====
func save_game(path: String = "user://save_game.dat") -> bool:
	var save_data: Dictionary = {
		"gold": gold,
		"reputation": reputation,
		"ingredients": ingredients,
		"fuel": fuel,
		"current_day": current_day,
		"guests_served_today": guests_served_today,
		"legendary_boost_days": legendary_boost_days,
		"golden_age_days": golden_age_days,
		"kitchen_upgrade_days": kitchen_upgrade_days,
		"facility_grid": facility_grid,
		"facility_types": facility_types
	}
	
	# 保存成就数据
	var achievements: Node = get_node_or_null("/root/Main/AchievementManager")
	if achievements and achievements.has_method("get_save_data"):
		save_data["achievements"] = achievements.get_save_data()
	
	# 保存员工数据
	var staff_mgr: Node = get_node_or_null("/root/Main/StaffManager")
	if staff_mgr and staff_mgr.has_method("get_save_data"):
		save_data["staff"] = staff_mgr.get_save_data()
	
	# 保存教程数据
	if tutorial and tutorial.has_method("save_tutorial_data"):
		save_data["tutorial"] = tutorial.save_tutorial_data()
	
	var save_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if save_file == null:
		push_error("Failed to open save file: " + path)
		return false
	
	var json_string: String = JSON.stringify(save_data, "\t")
	save_file.store_line(json_string)
	save_file.close()
	print("[Save] Game saved to: " + path)
	return true

func load_game(path: String = "user://save_game.dat") -> bool:
	if not FileAccess.file_exists(path):
		push_warning("Save file not found: " + path)
		return false
	
	var save_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if save_file == null:
		push_error("Failed to open save file: " + path)
		return false
	
	var json_string: String = save_file.get_line()
	save_file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save data")
		return false
	
	var save_data: Dictionary = json.get_data()
	if save_data.is_empty():
		push_error("Save data is empty")
		return false
	
	gold = int(save_data.get("gold", 100))
	reputation = int(save_data.get("reputation", 50))
	ingredients = int(save_data.get("ingredients", 20))
	fuel = int(save_data.get("fuel", 10))
	current_day = int(save_data.get("current_day", 1))
	guests_served_today = int(save_data.get("guests_served_today", 0))
	legendary_boost_days = int(save_data.get("legendary_boost_days", 0))
	golden_age_days = int(save_data.get("golden_age_days", 0))
	kitchen_upgrade_days = int(save_data.get("kitchen_upgrade_days", 0))
	facility_grid = save_data.get("facility_grid", [])
	facility_types = save_data.get("facility_types", {})
	
	# 加载成就数据
	var achievements: Node = get_node_or_null("/root/Main/AchievementManager")
	if achievements and achievements.has_method("load_save_data") and save_data.has("achievements"):
		achievements.load_save_data(save_data["achievements"])
	
	# 加载员工数据
	var staff_mgr: Node = get_node_or_null("/root/Main/StaffManager")
	if staff_mgr and staff_mgr.has_method("load_save_data") and save_data.has("staff"):
		staff_mgr.load_save_data(save_data["staff"])
	
	# 加载教程数据
	if tutorial and tutorial.has_method("load_tutorial_data") and save_data.has("tutorial"):
		tutorial.load_tutorial_data(save_data["tutorial"])
	
	# 清空现有客人
	active_guests.clear()
	
	# 重新生成客人
	for i in range(3):
		await get_tree().create_timer(0.3).timeout
		spawn_guest()
	
	_update_ui()
	print("[Save] Game loaded from: " + path)
	return true

# ===== 标题画面/游戏结束信号处理 =====
func _on_title_new_game() -> void:
	"""从标题画面开始新游戏"""
	# 重置所有游戏状态
	gold = 100
	reputation = 50
	ingredients = 20
	fuel = 10
	current_day = 1
	guests_served_today = 0
	income_today = 0
	legendary_boost_days = 0
	golden_age_days = 0
	kitchen_upgrade_days = 0
	build_mode = false
	selected_facility = ""
	hovered_cell = Vector2i(-1, -1)
	
	# 重新初始化网格（保留初始设施）
	_initialize_grid()
	
	# 清空客人
	active_guests.clear()
	
	# 生成初始客人
	for i in range(3):
		await get_tree().create_timer(0.5).timeout
		spawn_guest()
	
	_update_ui()
	
	# 通知成就系统重置
	var achievements: Node = get_node_or_null("/root/Main/AchievementManager")
	if achievements and achievements.has_method("reset_progress"):
		achievements.reset_progress()
	
	# 通知员工系统重置
	var staff_mgr: Node = get_node_or_null("/root/Main/StaffManager")
	if staff_mgr and staff_mgr.has_method("reset_progress"):
		staff_mgr.reset_progress()
	
	# 重置教程进度
	if tutorial and tutorial.has_method("reset_tutorial"):
		tutorial.reset_tutorial()
	
	# 播放背景音乐
	var audio: Node = get_node_or_null("/root/Main/AudioManager")
	if audio and audio.has_method("play_bgm"):
		audio.play_bgm("tavern")
	
	print("[Game] New game started")

func _on_title_load_game() -> void:
	"""从标题画面加载游戏"""
	var loaded: bool = await load_game()
	if loaded:
		print("[Game] Game loaded from title screen")
	else:
		# 加载失败，提示并开始新游戏
		push_warning("No save file found, starting new game")
		_on_title_new_game()

func _on_game_over_restart() -> void:
	"""重新开始游戏"""
	_on_title_new_game()

func _on_game_over_quit() -> void:
	"""返回标题画面"""
	# 显示标题画面
	var title_screen: Node = get_node_or_null("/root/Main/TitleScreen")
	if title_screen and title_screen.has_method("show_title"):
		title_screen.show_title()
