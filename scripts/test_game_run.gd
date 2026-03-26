extends SceneTree

func _init():
    print("[Game Test] Starting game test...")
    
    # 尝试加载主场景
    var main_scene = load("res://scenes/main.tscn")
    if main_scene == null:
        print("[Game Test] ERROR: Failed to load main scene")
        quit(1)
        return
    
    print("[Game Test] Main scene loaded successfully")
    
    # 实例化场景
    var instance = main_scene.instantiate()
    if instance == null:
        print("[Game Test] ERROR: Failed to instantiate main scene")
        quit(1)
        return
    
    print("[Game Test] Main scene instantiated successfully")
    root.add_child(instance)
    
    # 等待几帧让游戏初始化
    for i in range(5):
        await get_tree().process_frame
    
    print("[Game Test] Game ran for 5 frames - SUCCESS!")
    
    # 清理
    instance.queue_free()
    
    print("[Game Test] Test completed successfully!")
    quit(0)
