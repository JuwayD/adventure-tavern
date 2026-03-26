@tool
extends EditorPlugin

const PLUGIN_NAME = "godot_mcp"

func _enter_tree() -> void:
    print("[PluginEnabler] EditorPlugin entering tree...")
    
    # Wait a moment for other plugins to load
    await get_tree().create_timer(2.0).timeout
    
    print("[PluginEnabler] Attempting to enable plugin: " + PLUGIN_NAME)
    
    # Try to enable the Godot MCP plugin
    var enabled = set_plugin_enabled(PLUGIN_NAME, true)
    print("[PluginEnabler] Result: " + str(enabled))
    
    # Keep the plugin running
    print("[PluginEnabler] Plugin ready!")

func _exit_tree() -> void:
    print("[PluginEnabler] Exiting tree")
