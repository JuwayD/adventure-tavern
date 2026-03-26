extends Node

## 游戏管理器 - 单例模式

signal game_started()
signal game_over(reason: String)
signal card_selection_started(cards: Array)

var tavern: Node2D
var ui: CanvasLayer
var audio: Node
var is_running := false

# Roguelike 卡牌选择系统
var pending_card_choice := false
var available_cards: Array = []

func _ready() -> void:
	# 等待场景加载
	await get_tree().create_timer(0.5).timeout
	_initialize_game()

func _initialize_game() -> void:
	tavern = get_node_or_null("/root/Main")
	ui = get_node_or_null("/root/Main/UI")
	audio = get_node_or_null("/root/Main/AudioManager")
	
	if not tavern:
		push_error("Tavern scene not found!")
		return
	
	# 连接信号
	tavern.resource_changed.connect(_on_resource_changed)
	tavern.day_changed.connect(_on_day_changed)
	tavern.guest_arrived.connect(_on_guest_arrived)
	tavern.guest_left.connect(_on_guest_left)
	tavern.event_triggered.connect(_on_event_triggered)
	tavern.roguelike_card_requested.connect(_on_roguelike_card_requested)
	tavern.guest_clicked.connect(_on_guest_clicked)
	tavern.build_mode_changed.connect(_on_build_mode_changed)
	
	if ui:
		ui.build_requested.connect(_on_build_requested)
		ui.card_selected.connect(_on_card_selected)
		ui.guest_selected.connect(_on_guest_selected)
		ui.save_requested.connect(_on_save_requested)
		ui.load_requested.connect(_on_load_requested)
	
	is_running = true
	emit_signal("game_started")
	
	# 播放背景音乐
	if audio and audio.has_method("play_bgm"):
		audio.play_bgm("tavern")
	
	# 初始生成一些客人
	for i in range(3):
		await get_tree().create_timer(0.5).timeout
		tavern.spawn_guest()
	
	ui.show_message("欢迎来到冒险者酒馆!")

func _on_resource_changed(resource_name: String, new_value: int, old_value: int) -> void:
	if resource_name == "gold" and new_value < old_value:
		pass
	elif resource_name == "reputation":
		if new_value < old_value:
			ui.show_message("声誉下降!", 2.0)
		elif new_value > old_value:
			ui.show_message("声誉提升!", 2.0)

func _on_day_changed(day_number: int) -> void:
	ui.show_message("第 %d 天开始!" % day_number)

func _on_guest_arrived(guest_id: int) -> void:
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("guest_arrive")

func _on_guest_left(guest_id: int) -> void:
	pass

func _on_event_triggered(event_type: String, event_data: Dictionary) -> void:
	# 播放事件音效
	if audio and audio.has_method("play_sfx"):
		match event_type:
			"good":
				audio.play_sfx("good_event")
			"bad":
				audio.play_sfx("bad_event")
	ui.show_event(event_type, event_data)

func _on_roguelike_card_requested(cards: Array) -> void:
	# 显示卡牌选择界面
	available_cards = cards
	pending_card_choice = true
	ui.show_card_selection(cards)
	emit_signal("card_selection_started", cards)

func _on_card_selected(card_index: int) -> void:
	if not pending_card_choice or card_index < 0 or card_index >= available_cards.size():
		return
	
	var selected_card: Dictionary = available_cards[card_index]
	pending_card_choice = false
	
	# 播放卡牌选择音效
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("card_select")
	
	# 应用卡牌效果
	_apply_card_effect(selected_card)
	ui.hide_card_selection()
	ui.show_message("选择了: " + selected_card.get("name", "未知"))

func _apply_card_effect(card: Dictionary) -> void:
	match card.get("type", ""):
		"resource_boost":
			tavern.gold += card.get("gold", 0)
			tavern.ingredients += card.get("ingredients", 0)
			tavern.fuel += card.get("fuel", 0)
			tavern.reputation = mini(100, tavern.reputation + card.get("reputation", 0))
		"facility_boost":
			# 增强现有设施效果
			if card.get("id", "") == "kitchen_upgrade":
				tavern.kitchen_upgrade_days = 3
				ui.show_message("厨房升级! 食物收入翻倍，持续3天!", 3.0)
		"special":
			# 特殊事件
			_match_special_card(card.get("id", ""))

func _match_special_card(card_id: String) -> void:
	match card_id:
		"mysterious_merchant":
			tavern.gold += 40
			ui.show_message("神秘商人赠送了40金币!", 3.0)
		"adventurer_guild":
			tavern.reputation = mini(100, tavern.reputation + 8)
			ui.show_message("冒险者公会对你印象良好!", 3.0)
		"noble_recommendation":
			tavern.reputation = mini(100, tavern.reputation + 15)
			ui.show_message("贵族为你宣传，声誉大涨!", 3.0)
		"tavern_charm":
			# 所有客人小费+50%
			for guest in tavern.active_guests:
				guest["tip_multiplier"] = 1.5
			ui.show_message("酒馆魅力四射，客人小费+50%!", 3.0)
		"golden_age":
			tavern.golden_age_days = 2
			tavern.reputation = mini(100, tavern.reputation + 5)
			ui.show_message("黄金时代! 接下来2天无需消耗食材和燃料!", 4.0)
		"legendary_tavern":
			tavern.legendary_boost_days = 3
			tavern.reputation = mini(100, tavern.reputation + 5)
			ui.show_message("传奇酒馆! 收入+50% 持续3天!", 4.0)

func _on_build_requested(facility_type: String) -> void:
	"""进入建造模式，让玩家选择放置位置"""
	tavern.set_build_mode(true, facility_type)
	ui.set_build_mode(true)
	ui.show_message("点击地图上的绿色格子放置 %s" % facility_type)

func _on_build_mode_changed(in_build_mode: bool, facility_type: String) -> void:
	ui.set_build_mode(in_build_mode)

func _on_guest_clicked(guest_id: int) -> void:
	"""玩家点击了客人，显示客人详情"""
	var guest: Dictionary = tavern.get_guest_by_id(guest_id)
	if guest.is_empty():
		return
	
	# 检查订单是否已满足
	var order: Dictionary = guest.get("order", {})
	var has_order: bool = int(order.get("food", 0)) > 0 or int(order.get("drink", 0)) > 0 or int(order.get("luxury", 0)) > 0
	
	if not has_order:
		# 订单已满足，结账
		var payment: int = tavern.checkout_guest(guest_id)
		ui.show_message("客人支付了 %d 金币!" % payment)
	else:
		# 显示客人详情
		ui.show_guest_detail(guest)

func _on_guest_selected(guest_id: int) -> void:
	"""为选中的客人提供服务"""
	if tavern.active_guests.is_empty():
		return
	
	var result: Dictionary = tavern.serve_guest_all(guest_id)
	if result.get("success", false):
		# 播放服务成功音效
		if audio and audio.has_method("play_sfx"):
			audio.play_sfx("guest_served")
		ui.show_message(result.get("message", "服务完成!"))
		ui.hide_guest_detail()
		# 自动为已满足订单的客人结账
		for guest in tavern.active_guests:
			var order: Dictionary = guest.get("order", {})
			var has_order: bool = int(order.get("food", 0)) > 0 or int(order.get("drink", 0)) > 0 or int(order.get("luxury", 0)) > 0
			if not has_order:
				var payment: int = tavern.checkout_guest(guest["id"])
				# 播放金币音效
				if audio and audio.has_method("play_sfx"):
					audio.play_sfx("coin")
				ui.show_message("客人 %s 支付了 %d 金币!" % [guest.get("type", ""), payment])
				break
	else:
		ui.show_message(result.get("message", "服务失败!"))
		if audio and audio.has_method("play_sfx"):
			audio.play_sfx("error")

func _on_save_requested() -> void:
	if tavern.save_game():
		ui.show_message("游戏已保存!", 2.0)
	else:
		ui.show_message("保存失败!", 2.0)

func _on_load_requested() -> void:
	if tavern.load_game():
		ui.show_message("游戏已加载!", 2.0)
	else:
		ui.show_message("读取失败或无存档!", 2.0)

func _process(_delta: float) -> void:
	if not is_running:
		return
	
	if tavern and tavern.is_game_over():
		is_running = false
		var reason := ""
		if tavern.gold < 0:
			reason = "金币耗尽!"
		elif tavern.reputation <= 0:
			reason = "声誉扫地!"
		elif tavern.fuel <= 0:
			reason = "燃料耗尽!"
		emit_signal("game_over", reason)
		if ui:
			ui.show_message("游戏结束: " + reason, 999.0)
