extends Node
## 视觉效果管理器 - 粒子效果、浮动文字、屏幕特效

signal effect_played(effect_name: String)

# 粒子效果场景缓存
var _particle_scenes: Dictionary = {}

# 屏幕震动强度
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0

# 颜色过渡效果
var _color_tween: Tween = null
var _original_modulate: Color = Color.WHITE

func _ready() -> void:
	# 预加载粒子效果
	_particle_scenes = {
		"coin_spark": _create_coin_spark_scene(),
		"guest_arrival": _create_guest_arrival_scene(),
		"achievement": _create_achievement_scene(),
		"build_complete": _create_build_scene(),
		"card_select": _create_card_select_scene(),
		"bad_event": _create_bad_event_scene(),
		"resource_gain": _create_resource_gain_scene(),
		"resource_loss": _create_resource_loss_scene()
	}
	
	# 保存原始颜色
	if get_viewport().get_camera_2d():
		_original_modulate = get_viewport().get_camera_2d().modulate

func _process(delta: float) -> void:
	# 处理屏幕震动
	if _shake_timer > 0:
		_shake_timer -= delta
		if _shake_timer <= 0:
			_shake_timer = 0
			_shake_intensity = 0
			if get_viewport().get_camera_2d():
				get_viewport().get_camera_2d().offset = Vector2.ZERO
		else:
			# 随机震动
			var shake_offset = Vector2(
				randf_range(-1, 1) * _shake_intensity,
				randf_range(-1, 1) * _shake_intensity
			)
			if get_viewport().get_camera_2d():
				get_viewport().get_camera_2d().offset = shake_offset

## 播放粒子效果
func play_particle(effect_name: String, position: Vector2, parent: Node) -> void:
	if not _particle_scenes.has(effect_name):
		push_warning("Unknown particle effect: ", effect_name)
		return
	
	var scene = _particle_scenes[effect_name].instantiate()
	scene.position = position
	parent.add_child(scene)
	
	# 自动清理
	if scene is GPUParticles2D:
		scene.finished.connect(func(): scene.queue_free())
	elif scene.has_method("get_process_material"):
		var mat = scene.get_process_material()
		if mat:
			mat.lifetime = 1.0
			scene.finished.connect(func(): scene.queue_free())
	
	effect_played.emit(effect_name)

## 显示浮动文字
func show_floating_text(text: String, position: Vector2, parent: Node, 
	color: Color = Color.WHITE, font_size: int = 24, 
	duration: float = 1.5, offset_y: float = -50) -> void:
	
	var label = Label.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	
	# 添加阴影
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	parent.add_child(label)
	
	# 创建动画
	var tween = create_tween()
	tween.tween_property(label, "position:y", position.y + offset_y, duration)
	tween.tween_property(label, "modulate:a", 0, duration * 0.5)
	tween.tween_callback(func(): label.queue_free())

## 显示资源变化浮动文字
func show_resource_change(resource: String, amount: int, position: Vector2, parent: Node) -> void:
	var text = ""
	var color = Color.WHITE
	
	if amount > 0:
		text = "+%d %s" % [amount, _get_resource_icon(resource)]
		color = Color(0.4, 1, 0.4)  # 绿色
	elif amount < 0:
		text = "%d %s" % [amount, _get_resource_icon(resource)]
		color = Color(1, 0.4, 0.4)  # 红色
	else:
		return
	
	show_floating_text(text, position, parent, color, 20)

## 屏幕震动效果
func screen_shake(intensity: float = 10.0, duration: float = 0.3) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration

## 颜色过渡效果
func color_tint(target_color: Color, duration: float = 0.5) -> void:
	if _color_tween:
		_color_tween.kill()
	
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	_color_tween = create_tween()
	_color_tween.tween_property(camera, "modulate", target_color, duration)
	_color_tween.tween_property(camera, "modulate", _original_modulate, duration)

## 淡入淡出效果
func fade_transition(duration: float = 1.0, fade_in: bool = true) -> void:
	var canvas = ColorRect.new()
	canvas.color = Color.BLACK
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().get_gui_embedding_node().add_child(canvas)
	
	var tween = create_tween()
	if fade_in:
		canvas.modulate.a = 0
		tween.tween_property(canvas, "modulate:a", 1, duration * 0.5)
		tween.tween_property(canvas, "modulate:a", 0, duration * 0.5)
	else:
		canvas.modulate.a = 1
		tween.tween_property(canvas, "modulate:a", 0, duration)
	
	tween.tween_callback(func(): canvas.queue_free())

## 按钮点击动画
func animate_button(button: Button, scale_factor: float = 0.95) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(scale_factor, scale_factor), 0.1)
	tween.tween_property(button, "scale", Vector2(1, 1), 0.1)

## 面板弹出动画
func animate_panel_popup(panel: Control, duration: float = 0.3) -> void:
	panel.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1, duration)
	tween.tween_property(panel, "scale", Vector2(1, 1), duration)
	tween.set_ease(Tween.EASE_OUT_BACK)

## 创建金币火花粒子场景
func _create_coin_spark_scene() -> PackedScene:
	var scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 0.8
	particles.one_shot = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = ParticleProcessMaterial.DIRECTION_SPHERE_CONE
	material.spread = 45
	material.initial_velocity_min = 100
	material.initial_velocity_max = 200
	material.gravity = Vector3(0, 200, 0)
	
	var texture = _create_circle_texture(Color.GOLD)
	material.texture = texture
	
	particles.process_material = material
	scene.pack(particles)
	return scene

## 创建客人到达粒子场景
func _create_guest_arrival_scene() -> PackedScene:
	var scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = 0.6
	particles.one_shot = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = ParticleProcessMaterial.DIRECTION_UP
	material.spread = 30
	material.initial_velocity_min = 80
	material.initial_velocity_max = 150
	
	var texture = _create_circle_texture(Color(0.4, 0.8, 1))
	material.texture = texture
	
	particles.process_material = material
	scene.pack(particles)
	return scene

## 创建成就解锁粒子场景
func _create_achievement_scene() -> PackedScene:
	var scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.8
	
	var material = ParticleProcessMaterial.new()
	material.direction = ParticleProcessMaterial.DIRECTION_SPHERE_CONE
	material.spread = 360
	material.initial_velocity_min = 150
	material.initial_velocity_max = 300
	
	var texture = _create_star_texture(Color.GOLD)
	material.texture = texture
	
	particles.process_material = material
	scene.pack(particles)
	return scene

## 创建建造完成粒子场景
func _create_build_scene() -> PackedScene:
	var scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 12
	particles.lifetime = 0.5
	particles.one_shot = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = ParticleProcessMaterial.DIRECTION_SPHERE_CONE
	material.spread = 60
	material.initial_velocity_min = 60
	material.initial_velocity_max = 120
	
	var texture = _create_circle_texture(Color(0.6, 0.9, 0.6))
	material.texture = texture
	
	particles.process_material = material
	scene.pack(particles)
	return scene

## 创建卡牌选择粒子场景
func _create_card_select_scene() -> PackedScene:
	var scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 25
	particles.lifetime = 0.7
	particles.one_shot = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = ParticleProcessMaterial.DIRECTION_SPHERE_CONE
	material.spread = 90
	material.initial_velocity_min = 100
	material.initial_velocity_max = 200
	
	var texture = _create_circle_texture(Color(0.8, 0.6, 1))
	material.texture = texture
	
	particles.process_material = material
	scene.pack(particles)
	return scene

## 创建坏事件粒子场景
func _create_bad_event_scene() -> PackedScene:
	var scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 0.8
	particles.one_shot = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = ParticleProcessMaterial.DIRECTION_SPHERE_CONE
	material.spread = 45
	material.initial_velocity_min = 80
	material.initial_velocity_max = 150
	material.gravity = Vector3(0, -100, 0)  # 向下
	
	var texture = _create_circle_texture(Color(0.8, 0.3, 0.3))
	material.texture = texture
	
	particles.process_material = material
	scene.pack(particles)
	return scene

## 创建资源获得粒子场景
func _create_resource_gain_scene() -> PackedScene:
	var scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 10
	particles.lifetime = 0.6
	particles.one_shot = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = ParticleProcessMaterial.DIRECTION_UP
	material.spread = 20
	material.initial_velocity_min = 50
	material.initial_velocity_max = 100
	
	var texture = _create_circle_texture(Color(0.5, 1, 0.5))
	material.texture = texture
	
	particles.process_material = material
	scene.pack(particles)
	return scene

## 创建资源损失粒子场景
func _create_resource_loss_scene() -> PackedScene:
	var scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 10
	particles.lifetime = 0.6
	particles.one_shot = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = ParticleProcessMaterial.DIRECTION_DOWN
	material.spread = 20
	material.initial_velocity_min = 50
	material.initial_velocity_max = 100
	
	var texture = _create_circle_texture(Color(1, 0.5, 0.5))
	material.texture = texture
	
	particles.process_material = material
	scene.pack(particles)
	return scene

## 创建圆形纹理
func _create_circle_texture(color: Color) -> Texture2D:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	var center = Vector2(8, 8)
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x, y).distance_to(center)
			if dist > 7:
				image.set_pixel(x, y, Color.TRANSPARENT)
			else:
				var alpha = 1.0 - (dist / 8.0)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	
	var texture = ImageTexture.create_from_image(image)
	return texture

## 创建星形纹理
func _create_star_texture(color: Color) -> Texture2D:
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = Vector2(16, 16)
	var outer_radius = 14
	var inner_radius = 6
	
	for i in range(5):
		var angle_outer = (i * 2 * PI / 5) - PI / 2
		var angle_inner = angle_outer + PI / 5
		
		var outer_point = center + Vector2(cos(angle_outer), sin(angle_outer)) * outer_radius
		var inner_point = center + Vector2(cos(angle_inner), sin(angle_inner)) * inner_radius
		
		# 简单填充三角形
		_draw_triangle(image, center, outer_point, inner_point, color)
	
	var texture = ImageTexture.create_from_image(image)
	return texture

func _draw_triangle(image: Image, p1: Vector2, p2: Vector2, p3: Vector2, color: Color) -> void:
	# 简化的三角形绘制
	var points = [p1, p2, p3]
	var min_x = int(min(points[0].x, points[1].x, points[2].x))
	var max_x = int(max(points[0].x, points[1].x, points[2].x))
	var min_y = int(min(points[0].y, points[1].y, points[2].y))
	var max_y = int(max(points[0].y, points[1].y, points[2].y))
	
	for x in range(max(0, min_x), min(32, max_x + 1)):
		for y in range(max(0, min_y), min(32, max_y + 1)):
			if _point_in_triangle(Vector2(x, y), p1, p2, p3):
				image.set_pixel(x, y, color)

func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 = c - a
	var v1 = b - a
	var v2 = p - a
	
	var dot00 = v0.dot(v0)
	var dot01 = v0.dot(v1)
	var dot02 = v0.dot(v2)
	var dot11 = v1.dot(v1)
	var dot12 = v1.dot(v2)
	
	var inv_denom = 1.0 / (dot00 * dot11 - dot01 * dot01)
	var u = (dot11 * dot02 - dot01 * dot12) * inv_denom
	var v = (dot00 * dot12 - dot01 * dot02) * inv_denom
	
	return (u >= 0) and (v >= 0) and (u + v < 1)

## 获取资源图标
func _get_resource_icon(resource: String) -> String:
	match resource:
		"gold": return "💰"
		"reputation": return "⭐"
		"ingredients": return "🍖"
		"fuel": return "🪵"
		_: return ""
