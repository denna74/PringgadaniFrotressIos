extends SceneTree

var ok := true


func _check(label: String, cond: bool) -> void:
	if cond:
		print("OK  ", label)
	else:
		push_error("FAIL: " + label)
		ok = false


func _initialize() -> void:
	_run()


func _find_label(node: Node, text: String) -> Label:
	if node is Label and node.text == text:
		return node
	for child in node.get_children():
		var result: Label = _find_label(child, text)
		if result != null:
			return result
	return null


func _run() -> void:
	await process_frame

	var sm = root.get_node("/root/SaveManager")
	var tm = root.get_node("/root/TranslationManager")

	var page: Control = load("res://scenes/hub/ProfilePage.gd").new()
	root.add_child(page)
	await process_frame

	for label in ["HP", "ATK", "MP", "DEF", "STA"]:
		_check("profile shows %s label" % label, _find_label(page, label) != null)
	_check("profile drops the gold row", _find_label(page, tm.t("resource_gold")) == null)
	_check("profile registers no gold_changed listener", sm.gold_changed.get_connections().is_empty())

	page.queue_free()
	await process_frame
	await process_frame

	_check("no stale gold_changed listeners after page freed", sm.gold_changed.get_connections().is_empty())

	if ok:
		print("PROFILEPAGE_GOLD_PASS")
		quit(0)
	else:
		quit(1)
