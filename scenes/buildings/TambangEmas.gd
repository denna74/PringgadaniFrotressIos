extends Building


func can_open_overlay() -> bool:
	return false


func _init(data: Dictionary, plot_ref: Area3D) -> void:
	super._init(data, plot_ref)
