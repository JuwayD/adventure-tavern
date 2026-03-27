extends CanvasLayer

## 标题画面

signal new_game_started()
signal load_game_requested()

@onready var title_panel: PanelContainer = $TitlePanel
@onready var title_label: Label = $TitlePanel/TitleLabel
@onready var subtitle_label: Label = $TitlePanel/SubtitleLabel
@onready var new_game_button: Button = $TitlePanel/NewGameButton
@onready var load_game_button: Button = $TitlePanel/LoadGameButton
@onready var credits_button: Button = $TitlePanel/CreditsButton
@onready var version_label: Label = $TitlePanel/VersionLabel

var _showing_credits: bool = false

func _ready() -> void:
	_update_load_button()
	
	# 淡入效果
	var tween: Tween = create_tween()
	title_panel.modulate = Color(1, 1, 1, 0)
	tween.tween_property(title_panel, "modulate", Color(1, 1, 1, 1), 1.0)

func _update_load_button() -> void:
	var save_path: String = "user://save_game.dat"
	load_game_button.disabled = not FileAccess.file_exists(save_path)
	if load_game_button.disabled:
		load_game_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _on_new_game_button_pressed() -> void:
	emit_signal("new_game_started")
	# 淡出效果
	var tween: Tween = create_tween()
	tween.tween_property(title_panel, "modulate", Color(1, 1, 1, 0), 0.5)
	await tween.finished
	title_panel.visible = false

func _on_load_game_button_pressed() -> void:
	emit_signal("load_game_requested")
	# 淡出效果
	var tween: Tween = create_tween()
	tween.tween_property(title_panel, "modulate", Color(1, 1, 1, 0), 0.5)
	await tween.finished
	title_panel.visible = false

func _on_credits_button_pressed() -> void:
	if _showing_credits:
		# 返回
		title_label.text = "冒险者酒馆"
		subtitle_label.text = "模拟经营 · 肉鸽 · 建造"
		new_game_button.visible = true
		load_game_button.visible = true
		credits_button.text = "游戏信息"
		_showing_credits = false
	else:
		# 显示 credits
		title_label.text = "冒险者酒馆"
		subtitle_label.text = "感谢游玩！\n\n开发: AI Assistant\n引擎: Godot 4.6.1\n\n模拟经营 + 肉鸽 +\n建造 + 角色扮演"
		new_game_button.visible = false
		load_game_button.visible = false
		credits_button.text = "返回"
		_showing_credits = true

func show_title() -> void:
	title_panel.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(title_panel, "modulate", Color(1, 1, 1, 1), 0.5)
	_update_load_button()
	_showing_credits = false
	title_label.text = "冒险者酒馆"
	subtitle_label.text = "模拟经营 · 肉鸽 · 建造"
	new_game_button.visible = true
	load_game_button.visible = true
	credits_button.text = "游戏信息"
