extends Node2D

## 视觉特效管理器 - 处理粒子效果、浮动文字等

# 浮动文字场景（动态创建）
var floating_text_scene: PackedScene

# 粒子效果定义
const PARTICLE_EFFECTS: Dictionary = {
	"coin_spark": {
		"color": Color.GOLD,
		"amount": 10,
		"lifetime": 0.8,
		"speed": 80
	},
	"build_complete": {
		"color": Color(0.3, 0.8, 0.3),
		"amount": 15,
		"lifetime": 0.6,
		"speed": 60
	},
	"card_select": {
		"color": Color(0.9, 0.7, 0.4),
		"amount": 20,
		"lifetime": 1.0,
		"speed": 50
	}
}

func _ready() -> void:
	pass

func play_particle(effect_name: String, position: Vector2, parent: Node) -> void:
	"""播放粒子效果"""
	if not PARTICLE_EFFECTS.has(effect_name):
		return
	
	var effect_data: Dictionary = PARTICLE_EFFECTS[effect_name]
	
	# 创建 GPUParticles2D
	var particles: GPUParticles2D = GPUParticles2D.new()
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	
	process_material.amount = effect_data["amount"]
	process_material.lifetime = effect_data["lifetime"]
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 20
	process_material.initial_velocity_min = effect_data["speed"]
	process_material.initial_velocity_max = effect_data["speed"] * 1.5
	process_material.gravity = Vector3(0, 50, 0)
	
	var color_gradient: Gradient = Gradient.new()
	color_gradient.set_color(0, effect_data["color"])
	color_gradient.set_color(1, effect_data["color"] * Color(1, 1, 1, 0))
	process_material.color_gradient = color_gradient
	
	particles.process_material = process_material
	particles.position = position
	particles.one_shot = true
	particles.explosive = true
	
	parent.add_child(particles)
	particles.emitting = true
	
	# 自动清理
	var timer: Timer = Timer.new()
	timer.wait_time = effect_data["lifetime"] + 0.5
	timer.one_shot = true
	timer.timeout.connect(_cleanup_nodes.bind(particles, timer))
	parent.add_child(timer)
	timer.start()

func _cleanup_nodes(particles: Node, timer: Node) -> void:
	if is_instance_valid(particles):
		particles.queue_free()
	if is_instance_valid(timer):
		timer.queue_free()

func show_floating_text(text: String, position: Vector2, parent: Node, color: Color = Color.WHITE, font_size: int = 20) -> void:
	"""显示浮动文字"""
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	parent.add_child(label)
	
	# 向上浮动动画
	var tween: Tween = parent.create_tween()
	tween.tween_property(label, "position:y", position.y - 50, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.5)
	
	# 自动清理
	var timer: Timer = Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(_cleanup_nodes.bind(label, timer))
	parent.add_child(timer)
	timer.start()

func show_resource_change(resource_name: String, amount: int, position: Vector2, parent: Node) -> void:
	"""显示资源变化浮动文字"""
	var text: String = ""
	var color: Color = Color.WHITE
	
	match resource_name:
		"gold":
			text = "%+d💰" % amount
			color = Color.GOLD if amount > 0 else Color.RED
		"ingredients":
			text = "%+d🍖" % amount
			color = Color(0.6, 0.9, 0.4) if amount > 0 else Color.RED
		"reputation":
			text = "%+d⭐" % amount
			color = Color(0.5, 0.7, 1) if amount > 0 else Color.RED
		"fuel":
			text = "%+d🔥" % amount
			color = Color(1, 0.5, 0.3) if amount > 0 else Color.RED
	
	show_floating_text(text, position, parent, color, 18)
