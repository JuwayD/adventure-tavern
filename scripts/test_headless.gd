extends SceneTree

func _init():
    print("[Headless Test] Starting...")
    
    # Verify project loaded
    var config = ConfigFile.new()
    var err = config.load("res://project.godot")
    if err == OK:
        print("[Headless Test] project.godot loaded successfully")
        print("[Headless Test] Game name: " + config.get_value("application", "config/name", "unknown"))
    else:
        print("[Headless Test] ERROR: Failed to load project.godot")
    
    # List scenes
    var dir = DirAccess.open("res://scenes")
    if dir:
        dir.list_dir_begin()
        var file = dir.get_next()
        var scenes = []
        while file != "":
            if file.ends_with(".tscn"):
                scenes.append(file)
            file = dir.get_next()
        print("[Headless Test] Scenes found: " + str(scenes))
    else:
        print("[Headless Test] ERROR: Cannot open scenes directory")
    
    print("[Headless Test] Done!")
    quit()
