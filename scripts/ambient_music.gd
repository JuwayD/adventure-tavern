extends Node

## 环境音乐生成器 - 酒馆氛围音乐
## 简单的 A minor 和弦 drone (A2 + E3 + A3) 循环

var ambient_player: AudioStreamPlayer
var is_playing: bool = false
var volume: float = 0.45

const SAMPLE_RATE: float = 44100.0
const BUFFER_DURATION: float = 1.0  # 1秒循环

func _ready() -> void:
	print("[Ambient] Ready - generating 1s ambient drone")

func generate_ambient_stream() -> AudioStream:
	"""生成1秒的A minor和弦drone音频流"""
	print("[Ambient] Generating 1s ambient drone (A2+E3+A3 chord)...")
	var total_samples: int = int(BUFFER_DURATION * SAMPLE_RATE)
	var stereo_samples: PackedByteArray = PackedByteArray()
	stereo_samples.resize(total_samples * 4)

	# A minor和弦频率
	var freq_a2: float = 110.0  # A2
	var freq_e3: float = 164.81  # E3
	var freq_a3: float = 220.0  # A3 (八度)
	var freq_c4: float = 261.63  # C4 (minor third，增加氛围)

	# 相位
	var phase_a2: float = 0.0
	var phase_e3: float = 0.25  # 轻微相位偏移让声音更自然
	var phase_a3: float = 0.6
	var phase_c4: float = 0.1

	var phase_inc_a2: float = freq_a2 / SAMPLE_RATE
	var phase_inc_e3: float = freq_e3 / SAMPLE_RATE
	var phase_inc_a3: float = freq_a3 / SAMPLE_RATE
	var phase_inc_c4: float = freq_c4 / SAMPLE_RATE

	for i in range(total_samples):
		# 四个音的和弦 - 保持简单
		var s: float = 0.0
		s += sin(phase_a2 * 2.0 * PI) * 0.18
		s += sin(phase_e3 * 2.0 * PI) * 0.14
		s += sin(phase_a3 * 2.0 * PI) * 0.10
		s += sin(phase_c4 * 2.0 * PI) * 0.08  # minor third 增加忧郁感

		phase_a2 += phase_inc_a2
		phase_e3 += phase_inc_e3
		phase_a3 += phase_inc_a3
		phase_c4 += phase_inc_c4

		# 轻微的随机颤音 (每帧随机，很轻)
		s *= (1.0 + (randf() - 0.5) * 0.01)

		s = clamp(s, -0.85, 0.85)

		var s16: int = int(s * 32767.0 * volume)
		s16 = clamp(s16, -32768, 32767)
		stereo_samples[i * 4 + 0] = s16 & 0xFF
		stereo_samples[i * 4 + 1] = (s16 >> 8) & 0xFF
		stereo_samples[i * 4 + 2] = s16 & 0xFF
		stereo_samples[i * 4 + 3] = (s16 >> 8) & 0xFF

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.data = stereo_samples
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = int(SAMPLE_RATE)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	print("[Ambient] Generated ", total_samples, " samples, loop enabled")
	return stream

func play(generator: Node = null) -> void:
	if is_playing:
		return

	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = &"Master"
	add_child(ambient_player)

	var stream: AudioStream = generate_ambient_stream()
	ambient_player.stream = stream
	ambient_player.volume_db = linear_to_db(volume * 0.01)

	ambient_player.play()
	is_playing = true

	# 淡入
	var tween: Tween = create_tween()
	tween.tween_property(ambient_player, "volume_db", linear_to_db(volume), 3.0)
	print("[Ambient] Ambient music started - 1s chord drone looping")

func stop(fade_out: bool = true) -> void:
	if not is_playing or ambient_player == null:
		return

	if fade_out and is_instance_valid(ambient_player):
		var tween: Tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", linear_to_db(0.001), 2.0)
		await tween.finished

	ambient_player.stop()
	ambient_player.queue_free()
	ambient_player = null
	is_playing = false
	print("[Ambient] Ambient music stopped")

func set_volume(vol: float) -> void:
	volume = clamp(vol, 0.0, 1.0)
	if ambient_player and is_instance_valid(ambient_player):
		ambient_player.volume_db = linear_to_db(volume)

func get_is_playing() -> bool:
	return is_playing
