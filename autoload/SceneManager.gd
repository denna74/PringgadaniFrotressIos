extends Node


var _pending_params: Dictionary = {}
var _current_scene: Node = null


func _ready() -> void:
    var root: Window = get_tree().root
    _current_scene = root.get_child(root.get_child_count() - 1)


func go_to_scene(path: String, params: Dictionary = {}) -> void:
    _pending_params = params.duplicate()
    call_deferred("_deferred_switch_scene", path)


func _deferred_switch_scene(path: String) -> void:
    GamePause.clear()
    if _current_scene:
        _current_scene.queue_free()

    var new_scene: PackedScene = ResourceLoader.load(path)
    _current_scene = new_scene.instantiate()
    get_tree().root.add_child(_current_scene)
    get_tree().current_scene = _current_scene


func get_param(key: String, default = null):
    if _pending_params.has(key):
        var val = _pending_params[key]
        _pending_params.erase(key)
        return val
    return default
