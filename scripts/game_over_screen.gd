extends CanvasLayer

## 游戏结束画面

signal restart_requested()
signal quit_to_title_requested()

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOverLabel
@onready var reason_label: Label = $GameOverPanel/ReasonLabel
@onready var stats_label: Label = $GameOverPanel/StatsLabel
@onready var restart_button: Button = $GameOverPanel/RestartButton
@onready var quit_button: Button = $GameOverPanel/QuitButton

func _ready() -> void:
	game_over_panel.visible = false

func show_game_over(reason: String) -> void:
	# 从酒馆获取统计数据
	var tavern = get_node_or_null("/root/Main")
	var game_mgr = get_node_or_null("/root/Main/GameManager")
	
	var stats: Dictionary = {
		"days": 1,
		"guests_served": 0,
		"total_gold": 0,
		"max_reputation": 0
	}
	
	if tavern:
		stats["days"] = tavern.current_day
		stats["guests_served"] = tavern.guests_served_today
		stats["total_gold"] = tavern.gold  # 当前金币
	if game_mgr:
		# 尝试从成就系统获取累计金币
		var achievements = get_node_or_null("/root/Main/AchievementManager")
		if achievements and achievements.has_method("get_save_data"):
			var ach_data = achievements.get_save_data()
			stats["total_gold"] = ach_data.get("stats", {}).get("gold_earned_total", tavern.gold if tavern else 0)
			stats["guests_served"] = ach_data.get("stats", {}).get("guests_served_total", 0)
	
	# 设置失败原因
	reason_label.text = reason
	
	# 设置统计信息
	var stats_text: String = "游戏统计\n"
	stats_text += "─────────────────\n"
	stats_text += "存活天数: %d 天\n" % stats.get("days", 1)
	stats_text += "服务客人: %d 位\n" % stats.get("guests_served", 0)
	stats_text += "累计金币: %d 金\n" % stats.get("total_gold", 0)
	stats_text += "最高声誉: %d\n" % stats.get("max_reputation", 0)
	stats_label.text = stats_text
	
	# 显示面板
	game_over_panel.visible = true
	
	# 淡入效果
	var tween: Tween = create_tween()
	game_over_panel.modulate = Color(1, 1, 1, 0)
	tween.tween_property(game_over_panel, "modulate", Color(1, 1, 1, 1), 0.8)

func _on_restart_button_pressed() -> void:
	emit_signal("restart_requested")
	game_over_panel.visible = false

func _on_quit_button_pressed() -> void:
	emit_signal("quit_to_title_requested")
	game_over_panel.visible = false
