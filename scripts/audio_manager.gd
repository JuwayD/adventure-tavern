extends Node

## 音频管理器 - 处理背景音乐和音效

# 音量设置
var master_volume: float = 0.8
var bgm_volume: float = 0.5
var sfx_volume: float = 0.7

# 背景音乐播放器
var bgm_player: AudioStreamPlayer
var bgm_playing: bool = false
var current_bgm: String = ""

# 音效播放器池
var sfx_players: Array = []
const SFX_POOL_SIZE: int = 4

# 环境音乐生成器
var ambient_music: Node = null

# 背景音乐资源路径
const BGM_PATHS: Dictionary = {
	"tavern": "res://assets/audio/bgm/tavern_theme.ogg",
	"peaceful": "res://assets/audio/bgm/peaceful_day.ogg",
	"event": "res://assets/audio/bgm/event_music.ogg"
}

# 音效资源路径
const SFX_PATHS: Dictionary = {
	"guest_arrive": "res://assets/audio/sfx/guest_arrive.ogg",
	"guest_served": "res://assets/audio/sfx/guest_served.ogg",
	"coin": "res://assets/audio/sfx/coin.ogg",
	"build": "res://assets/audio/sfx/build.ogg",
	"card_select": "res://assets/audio/sfx/card_select.ogg",
	"day_change": "res://assets/audio/sfx/day_change.ogg",
	"good_event": "res://assets/audio/sfx/good_event.ogg",
	"bad_event": "res://assets/audio/sfx/bad_event.ogg",
	"ui_click": "res://assets/audio/sfx/ui_click.ogg",
	"error": "res://assets/audio/sfx/error.ogg"
}

func _ready() -> void:
	_initialize_audio()

func _initialize_audio() -> void:
	# 创建背景音乐播放器
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = &"Master"
	bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
	add_child(bgm_player)
	
	# 创建环境音乐生成器
	ambient_music = Node.new()
	ambient_music.name = "AmbientMusic"
	add_child(ambient_music)
	
	# 创建音效播放器池
	for i in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = &"Master"
		player.volume_db = linear_to_db(sfx_volume * master_volume)
		add_child(player)
		sfx_players.append(player)

func _get_available_sfx_player() -> AudioStreamPlayer:
	"""获取一个可用的音效播放器"""
	for player in sfx_players:
		if not player.playing:
			return player
	# 如果所有播放器都在使用，返回第一个
	return sfx_players[0]

func play_bgm(bgm_name: String, fade_in: bool = true) -> void:
	"""播放背景音乐"""
	# 如果正在播放环境音乐，先停止
	if ambient_music and ambient_music.has_method("get_is_playing") and ambient_music.get_is_playing():
		ambient_music.stop()
	
	if not BGM_PATHS.has(bgm_name):
		# 尝试使用环境音乐作为通用背景
		_start_ambient_music()
		return
	
	var path: String = BGM_PATHS[bgm_name]
	if not ResourceLoader.exists(path):
		# 文件不存在，使用程序化环境音乐
		_start_ambient_music()
		return
	
	var stream: AudioStream = load(path)
	if stream == null:
		_start_ambient_music()
		return
	
	bgm_player.stream = stream
	bgm_player.volume_db = linear_to_db(bgm_volume * master_volume * 0.01) if fade_in else linear_to_db(bgm_volume * master_volume)
	bgm_player.play()
	bgm_playing = true
	current_bgm = bgm_name
	
	if fade_in:
		_fade_in_bgm()

func _start_ambient_music() -> void:
	"""启动程序化环境音乐"""
	if ambient_music == null:
		return
	
	# 检查是否已经有生成的脚本
	var script_path: String = "res://scripts/ambient_music.gd"
	if not ResourceLoader.exists(script_path):
		print("[AudioManager] Ambient music script not found!")
		return
	
	var ambient_script: GDScript = load(script_path)
	if ambient_script == null:
		print("[AudioManager] Failed to load ambient music script!")
		return
	
	# 创建环境音乐节点
	var ambient_node: Node = Node.new()
	ambient_node.set_script(ambient_script)
	ambient_node.name = "AmbientMusicInstance"
	
	# 替换旧的 ambient_music 引用
	remove_child(ambient_music)
	ambient_music.queue_free()
	ambient_music = ambient_node
	add_child(ambient_node)
	
	# 播放环境音乐
	if ambient_node.has_method("play"):
		ambient_node.play()
		bgm_playing = true
		current_bgm = "ambient"
		print("[AudioManager] Playing procedural ambient music")

func _fade_in_bgm() -> void:
	"""背景音乐淡入"""
	var target_db: float = linear_to_db(bgm_volume * master_volume)
	var steps: int = 20
	var step_duration: float = 0.1
	for i in range(steps):
		await get_tree().create_timer(step_duration).timeout
		var t: float = float(i) / float(steps)
		bgm_player.volume_db = linear_to_db((bgm_volume * master_volume) * t + 0.001)

func stop_bgm(fade_out: bool = true) -> void:
	"""停止背景音乐"""
	if not bgm_playing:
		return
	
	# 停止环境音乐
	if ambient_music and ambient_music.has_method("stop"):
		ambient_music.stop()
	
	if fade_out:
		await _fade_out_bgm()
	
	bgm_player.stop()
	bgm_playing = false
	current_bgm = ""

func _fade_out_bgm() -> void:
	"""背景音乐淡出"""
	var steps: int = 10
	var step_duration: float = 0.1
	for i in range(steps):
		await get_tree().create_timer(step_duration).timeout
		var t: float = 1.0 - float(i) / float(steps)
		bgm_player.volume_db = linear_to_db((bgm_volume * master_volume) * t + 0.001)
	
	bgm_player.volume_db = linear_to_db(0.001)

func play_sfx(sfx_name: String) -> void:
	"""播放音效"""
	if not SFX_PATHS.has(sfx_name):
		push_warning("[Audio] SFX not found: " + sfx_name)
		return
	
	var path: String = SFX_PATHS[sfx_name]
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	
	if stream == null:
		# 如果没有找到音效文件，使用合成音效
		_play_synthetic_sfx(sfx_name)
		return
	
	var player: AudioStreamPlayer = _get_available_sfx_player()
	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume * master_volume)
	player.play()

func _play_synthetic_sfx(sfx_name: String) -> void:
	"""播放合成音效（当没有音频文件时）"""
	var player: AudioStreamPlayer = _get_available_sfx_player()
	player.volume_db = linear_to_db(sfx_volume * master_volume)
	
	# 预生成音效并播放
	match sfx_name:
		"coin":
			# 金币声 - 短促的高频音，两音符上跳
			var stream1: AudioStreamWAV = _generate_wav_tone(800, 0.08, 0.25)
			var stream2: AudioStreamWAV = _generate_wav_tone(1200, 0.1, 0.2)
			player.stream = stream1
			player.play()
			_sfx_chain_player(player, stream2, 0.1)
		"guest_arrive":
			# 客人到达 - 中等频率的提示音
			player.stream = _generate_wav_tone(440, 0.3, 0.2)
			player.play()
		"guest_served":
			# 服务完成 - 上升三音符
			var s1: AudioStreamWAV = _generate_wav_tone(523, 0.15, 0.2)
			var s2: AudioStreamWAV = _generate_wav_tone(659, 0.12, 0.18)
			var s3: AudioStreamWAV = _generate_wav_tone(784, 0.15, 0.15)
			player.stream = s1
			player.play()
			_sfx_chain_player(player, s2, 0.12)
			_sfx_chain_player(player, s3, 0.1)
		"build":
			# 建造 - 低沉的锤击声
			player.stream = _generate_wav_tone(150, 0.2, 0.35)
			player.play()
		"card_select":
			# 卡牌选择 - 清脆的声音
			player.stream = _generate_wav_tone(660, 0.15, 0.2)
			player.play()
		"day_change":
			# 日期变化 - 钟声（和弦）
			player.stream = _generate_wav_chord([262, 330, 392], 0.6)
			player.play()
		"good_event":
			# 好事件 - 欢快的和弦
			player.stream = _generate_wav_chord([523, 659, 784], 0.5)
			player.play()
		"bad_event":
			# 坏事件 - 下沉的音调
			player.stream = _generate_wav_tone(196, 0.4, 0.25)
			player.play()
		"ui_click":
			# UI点击 - 轻微的点击声
			player.stream = _generate_wav_tone(1000, 0.05, 0.12)
			player.play()
		"error":
			# 错误 - 下降的警示音
			var e1: AudioStreamWAV = _generate_wav_tone(300, 0.15, 0.2)
			var e2: AudioStreamWAV = _generate_wav_tone(250, 0.15, 0.18)
			player.stream = e1
			player.play()
			_sfx_chain_player(player, e2, 0.18)
		_:
			# 默认 - 简单的哔声
			player.stream = _generate_wav_tone(440, 0.1, 0.2)
			player.play()

func _sfx_chain_player(player: AudioStreamPlayer, next_stream: AudioStreamWAV, delay: float) -> void:
	"""在当前音效播完后播放下一个音效"""
	var timer: SceneTreeTimer = get_tree().create_timer(delay)
	timer.timeout.connect(_play_stream_on_player.bind(player, next_stream))

func _play_stream_on_player(player: AudioStreamPlayer, stream: AudioStreamWAV) -> void:
	if player != null and is_instance_valid(player):
		player.stream = stream
		player.play()

func _generate_wav_tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	"""生成单音调 WAV 音频流"""
	var mix_rate: float = 44100.0
	var total_samples: int = int(duration * mix_rate)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(total_samples * 2 * 2)  # stereo, 16-bit
	
	var phase: float = 0.0
	var phase_increment: float = frequency / mix_rate
	
	# ADSR 包络参数
	var attack_samples: int = int(0.005 * mix_rate)   # 5ms 攻击
	var release_samples: int = int(0.05 * mix_rate)   # 50ms 释放
	
	for i in range(total_samples):
		var envelope: float = 1.0
		# Attack
		if i < attack_samples:
			envelope = float(i) / float(attack_samples)
		# Hold then release
		elif i > total_samples - release_samples:
			envelope = float(total_samples - i) / float(release_samples)
		
		var sample: float = sin(phase * 2.0 * PI) * volume * envelope
		phase += phase_increment
		if phase >= 1.0:
			phase -= 1.0
		
		# 16-bit stereo little-endian
		var s16: int = int(sample * 32767.0)
		samples[i * 4 + 0] = s16 & 0xFF
		samples[i * 4 + 1] = (s16 >> 8) & 0xFF
		samples[i * 4 + 2] = s16 & 0xFF
		samples[i * 4 + 3] = (s16 >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.data = samples
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = int(mix_rate)
	return stream

func _generate_wav_chord(frequencies: Array, duration: float) -> AudioStreamWAV:
	"""生成和弦 WAV 音频流"""
	var mix_rate: float = 44100.0
	var total_samples: int = int(duration * mix_rate)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(total_samples * 2 * 2)  # stereo, 16-bit
	
	var phases: Array = []
	var phase_increments: Array = []
	for f in frequencies:
		phases.append(0.0)
		phase_increments.append(float(f) / mix_rate)
	
	var attack_samples: int = int(0.01 * mix_rate)
	var release_samples: int = int(0.1 * mix_rate)
	var volume: float = 0.25 / float(frequencies.size())
	
	for i in range(total_samples):
		var envelope: float = 1.0
		if i < attack_samples:
			envelope = float(i) / float(attack_samples)
		elif i > total_samples - release_samples:
			envelope = float(total_samples - i) / float(release_samples)
		
		var mixed: float = 0.0
		for j in range(frequencies.size()):
			mixed += sin(phases[j] * 2.0 * PI)
			phases[j] += phase_increments[j]
			if phases[j] >= 1.0:
				phases[j] -= 1.0
		
		mixed = (mixed / float(frequencies.size())) * volume * envelope
		
		var s16: int = int(mixed * 32767.0)
		samples[i * 4 + 0] = s16 & 0xFF
		samples[i * 4 + 1] = (s16 >> 8) & 0xFF
		samples[i * 4 + 2] = s16 & 0xFF
		samples[i * 4 + 3] = (s16 >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.data = samples
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = int(mix_rate)
	return stream

func set_master_volume(vol: float) -> void:
	master_volume = clamp(vol, 0.0, 1.0)
	_update_volumes()

func set_bgm_volume(vol: float) -> void:
	bgm_volume = clamp(vol, 0.0, 1.0)
	bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
	# 同时设置环境音乐音量
	if ambient_music and ambient_music.has_method("set_volume"):
		ambient_music.set_volume(bgm_volume)

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clamp(vol, 0.0, 1.0)
	for player in sfx_players:
		player.volume_db = linear_to_db(sfx_volume * master_volume)

func _update_volumes() -> void:
	bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
	for player in sfx_players:
		player.volume_db = linear_to_db(sfx_volume * master_volume)

func is_bgm_playing() -> bool:
	if bgm_playing:
		return true
	if ambient_music and ambient_music.has_method("get_is_playing"):
		return ambient_music.get_is_playing()
	return false

func get_current_bgm() -> String:
	if current_bgm != "":
		return current_bgm
	if ambient_music and ambient_music.has_method("get_is_playing") and ambient_music.get_is_playing():
		return "ambient"
	return current_bgm
