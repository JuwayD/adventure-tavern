extends Node

## Game Manager - Singleton Pattern

signal game_began()
signal game_over(reason: String)
signal card_selection_started(cards: Array)

var tavern: Node2D
var ui: CanvasLayer
var audio: Node
var achievements: Node
var tutorial: Node
var is_running := false
var game_started := false

# Roguelike card selection system
var pending_card_choice := false
var available_cards: Array = []

# Cumulative gold for achievement tracking
var total_gold_earned: int = 0

# Max reputation record
var max_reputation: int = 50

func _ready() -> void:
	# Wait for scene to load
	await get_tree().create_timer(0.5).timeout
	_initialize_game()
	# Pause game loop, wait for title screen
	process_mode = 3  # PROCESS_MODE_DISABLED = 3

func _initialize_game() -> void:
	tavern = get_node_or_null("/root/Main")
	ui = get_node_or_null("/root/Main/UI")
	audio = get_node_or_null("/root/Main/AudioManager")
	achievements = get_node_or_null("/root/Main/AchievementManager")
	tutorial = get_node_or_null("/root/Main/TutorialManager")
	
	if not tavern:
		push_error("Tavern scene not found!")
		return
	
	# Connect title screen signals
	var title_screen: Node = get_node_or_null("/root/Main/TitleScreen")
	if title_screen:
		title_screen.new_game_started.connect(_on_title_new_game_started)
		title_screen.load_game_requested.connect(_on_title_load_game_requested)
	
	# Initialize achievement system UI
	if achievements and achievements.has_method("initialize_ui"):
		achievements.initialize_ui(ui)
	
	# Connect signals
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
	
	# Connect tutorial signals
	if tutorial:
		tutorial.tutorial_finished.connect(_on_tutorial_finished)
	
	is_running = false
	game_started = false
	emit_signal("game_began")

func _on_title_new_game_started() -> void:
	"""Title screen: new game clicked"""
	print("[GameManager] Title: New game started")
	total_gold_earned = 0
	max_reputation = 50
	
	# Hide title screen
	var title_screen: CanvasLayer = get_node_or_null("/root/Main/TitleScreen")
	if title_screen:
		title_screen.visible = false
		print("[GameManager] Title screen hidden")
	else:
		print("[GameManager] ERROR: Title screen not found!")
	
	is_running = true
	game_started = true
	
	# Notify tavern to start new game
	if tavern and tavern.has_method("_on_title_new_game"):
		tavern._on_title_new_game()
	
	# Connect achievement unlock signal
	if achievements and achievements.has_signal("achievement_unlocked"):
		achievements.connect("achievement_unlocked", _on_achievement_unlocked)
	
	# Play background music
	if audio and audio.has_method("play_bgm"):
		audio.play_bgm("tavern")
	
	# Show welcome message
	if ui:
		ui.show_message("Welcome to Adventurer's Tavern!")
	
	# Start tutorial for new games
	if tutorial and tutorial.has_method("start_tutorial"):
		tutorial.start_tutorial()
	
	process_mode = 0  # PROCESS_MODE_INHERITED = 0

func _on_title_load_game_requested() -> void:
	"""Title screen: load game clicked"""
	print("[GameManager] Title: Load game requested")
	total_gold_earned = 0
	
	# Hide title screen
	var title_screen: Node = get_node_or_null("/root/Main/TitleScreen")
	if title_screen:
		title_screen.visible = false
	
	is_running = true
	game_started = true
	
	# Load game
	if tavern and tavern.has_method("load_game"):
		var loaded: bool = await tavern.load_game()
		if loaded:
			# Sync achievement stats
			if achievements and achievements.has_method("get_save_data"):
				var ach_data: Dictionary = achievements.get_save_data()
				total_gold_earned = ach_data.get("stats", {}).get("gold_earned_total", 0)
			if ui:
				ui.show_message("Game loaded!")
		else:
			# No save, start new game
			if tavern.has_method("_on_title_new_game"):
				tavern._on_title_new_game()
			if ui:
				ui.show_message("No save found, starting new game!")
	else:
		# tavern has no load_game method, start new game
		if tavern and tavern.has_method("_on_title_new_game"):
			tavern._on_title_new_game()
	
	# Connect achievement unlock signal
	if achievements and achievements.has_signal("achievement_unlocked"):
		achievements.connect("achievement_unlocked", _on_achievement_unlocked)
	
	# Play background music
	if audio and audio.has_method("play_bgm"):
		audio.play_bgm("tavern")
	
	process_mode = 0  # PROCESS_MODE_INHERITED = 0

func start_game_from_title() -> void:
	"""Called externally to start game from title (legacy compatibility)"""
	_on_title_new_game_started()

func _on_resource_changed(resource_name: String, new_value: int, old_value: int) -> void:
	if resource_name == "gold":
		if new_value > old_value:
			total_gold_earned += (new_value - old_value)
			# Update achievement stats: total gold earned
			if achievements and achievements.has_method("update_stat"):
				achievements.update_stat("gold_earned_total", total_gold_earned)
	elif resource_name == "reputation":
		if new_value > max_reputation:
			max_reputation = new_value
		if new_value < old_value:
			ui.show_message("Reputation decreased!", 2.0)
		elif new_value > old_value:
			ui.show_message("Reputation increased!", 2.0)
			# Update reputation achievement
			if achievements and achievements.has_method("update_stat"):
				achievements.update_stat("reputation", new_value)

func _on_day_changed(day_number: int) -> void:
	ui.show_message("Day %d begins!" % day_number)
	# Update survival days achievement
	if achievements and achievements.has_method("update_stat"):
		achievements.update_stat("days_survived", day_number)

func _on_achievement_unlocked(achievement_id: String, achievement_name: String) -> void:
	"""Show notification when achievement is unlocked"""
	ui.show_message("Achievement Unlocked: " + achievement_name, 4.0)
	# Play achievement sound
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("good_event")

func _on_tutorial_finished() -> void:
	"""Tutorial completed or skipped"""
	print("[GameManager] Tutorial finished")
	# Tutorial bonuses could be applied here if desired

func _on_guest_arrived(guest_id: int) -> void:
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("guest_arrive")

func _on_guest_left(guest_id: int) -> void:
	pass

func _on_event_triggered(event_type: String, event_data: Dictionary) -> void:
	# Play event sound
	if audio and audio.has_method("play_sfx"):
		match event_type:
			"good":
				audio.play_sfx("good_event")
				# Good event achievement
				if achievements and achievements.has_method("increment_stat"):
					achievements.increment_stat("good_events_triggered")
			"bad":
				audio.play_sfx("bad_event")
	ui.show_event(event_type, event_data)

func _on_roguelike_card_requested(cards: Array) -> void:
	# Show card selection UI
	available_cards = cards
	pending_card_choice = true
	ui.show_card_selection(cards)
	emit_signal("card_selection_started", cards)

func _on_card_selected(card_index: int) -> void:
	if not pending_card_choice or card_index < 0 or card_index >= available_cards.size():
		return
	
	var selected_card: Dictionary = available_cards[card_index]
	pending_card_choice = false
	
	# Play card selection sound
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("card_select")
	
	# Apply card effect
	_apply_card_effect(selected_card)
	ui.hide_card_selection()
	ui.show_message("Selected: " + selected_card.get("name", "Unknown"))
	# Update card selection achievement
	if achievements and achievements.has_method("increment_stat"):
		achievements.increment_stat("cards_selected")

func _apply_card_effect(card: Dictionary) -> void:
	match card.get("type", ""):
		"resource_boost":
			tavern.gold += card.get("gold", 0)
			tavern.ingredients += card.get("ingredients", 0)
			tavern.fuel += card.get("fuel", 0)
			tavern.reputation = mini(100, tavern.reputation + card.get("reputation", 0))
		"facility_boost":
			# Enhance existing facility effects
			if card.get("id", "") == "kitchen_upgrade":
				tavern.kitchen_upgrade_days = 3
				ui.show_message("Kitchen upgraded! Food income doubled for 3 days!", 3.0)
		"special":
			# Special events
			_match_special_card(card.get("id", ""))

func _match_special_card(card_id: String) -> void:
	match card_id:
		"mysterious_merchant":
			tavern.gold += 40
			ui.show_message("Mysterious merchant gifted you 40 gold!", 3.0)
		"adventurer_guild":
			tavern.reputation = mini(100, tavern.reputation + 8)
			ui.show_message("Adventurer's Guild is pleased with you!", 3.0)
		"noble_recommendation":
			tavern.reputation = mini(100, tavern.reputation + 15)
			ui.show_message("A noble recommended you! Reputation soars!", 3.0)
		"tavern_charm":
			# All guests tip +50%
			for guest in tavern.active_guests:
				guest["tip_multiplier"] = 1.5
			ui.show_message("Tavern charm activated! Guests tip +50%%!", 3.0)
		"golden_age":
			tavern.golden_age_days = 2
			tavern.reputation = mini(100, tavern.reputation + 5)
			ui.show_message("Golden Age! No ingredients or fuel consumed for 2 days!", 4.0)
		"legendary_tavern":
			tavern.legendary_boost_days = 3
			tavern.reputation = mini(100, tavern.reputation + 5)
			ui.show_message("Legendary Tavern! Income +50%% for 3 days!", 4.0)

func _on_build_requested(facility_type: String) -> void:
	"""Enter build mode, let player choose placement"""
	tavern.set_build_mode(true, facility_type)
	ui.set_build_mode(true)
	ui.show_message("Click a green cell on the map to place %s" % facility_type)

func _on_build_mode_changed(in_build_mode: bool, facility_type: String) -> void:
	ui.set_build_mode(in_build_mode)

func _on_guest_clicked(guest_id: int) -> void:
	"""Player clicked on a guest, show guest detail"""
	var guest: Dictionary = tavern.get_guest_by_id(guest_id)
	if guest.is_empty():
		return
	
	# Check if order is already satisfied
	var order: Dictionary = guest.get("order", {})
	var has_order: bool = int(order.get("food", 0)) > 0 or int(order.get("drink", 0)) > 0 or int(order.get("luxury", 0)) > 0
	
	if not has_order:
		# Order satisfied, checkout
		var payment: int = tavern.checkout_guest(guest_id)
		ui.show_message("Guest paid %d gold!" % payment)
		# Update guests served achievement
		if achievements and achievements.has_method("increment_stat"):
			achievements.increment_stat("guests_served_total")
	else:
		# Show guest detail
		ui.show_guest_detail(guest)

func _on_guest_selected(guest_id: int) -> void:
	"""Serve the selected guest"""
	if tavern.active_guests.is_empty():
		return
	
	var result: Dictionary = tavern.serve_guest_all(guest_id)
	if result.get("success", false):
		# Play service success sound
		if audio and audio.has_method("play_sfx"):
			audio.play_sfx("guest_served")
		ui.show_message(result.get("message", "Service complete!"))
		ui.hide_guest_detail()
		# Auto checkout guests whose orders are satisfied
		for guest in tavern.active_guests:
			var g_order: Dictionary = guest.get("order", {})
			var g_has_order: bool = int(g_order.get("food", 0)) > 0 or int(g_order.get("drink", 0)) > 0 or int(g_order.get("luxury", 0)) > 0
			if not g_has_order:
				var payment: int = tavern.checkout_guest(guest["id"])
				# Play coin sound
				if audio and audio.has_method("play_sfx"):
					audio.play_sfx("coin")
				ui.show_message("Guest %s paid %d gold!" % [guest.get("type", ""), payment])
				# Update guests served achievement
				if achievements and achievements.has_method("increment_stat"):
					achievements.increment_stat("guests_served_total")
				break
	else:
		ui.show_message(result.get("message", "Service failed!"))
		if audio and audio.has_method("play_sfx"):
			audio.play_sfx("error")

func _on_save_requested() -> void:
	if tavern.save_game():
		ui.show_message("Game saved!", 2.0)
	else:
		ui.show_message("Save failed!", 2.0)

func _on_load_requested() -> void:
	if tavern.load_game():
		ui.show_message("Game loaded!", 2.0)
		# Sync achievement stats to game_manager
		if achievements and achievements.has_method("get_save_data"):
			var ach_data: Dictionary = achievements.get_save_data()
			total_gold_earned = ach_data.get("stats", {}).get("gold_earned_total", 0)
	else:
		ui.show_message("Load failed or no save!", 2.0)

func _process(_delta: float) -> void:
	if not is_running or not game_started:
		return
	
	if tavern and tavern.is_game_over():
		is_running = false
		var reason := ""
		if tavern.gold < 0:
			reason = "Gold depleted!"
		elif tavern.reputation <= 0:
			reason = "Reputation ruined!"
		elif tavern.fuel <= 0:
			reason = "Fuel exhausted!"
		emit_signal("game_over", reason)

func _on_game_over_signal(reason: String) -> void:
	"""Handle game over"""
	print("[GameManager] Game over: ", reason)
	if ui:
		ui.show_message("Game Over: " + reason, 999.0)
	
	# Stop background music
	if audio and audio.has_method("stop_bgm"):
		audio.stop_bgm()
