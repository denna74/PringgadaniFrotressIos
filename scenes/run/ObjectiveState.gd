class_name ObjectiveState extends RefCounted

## Tracks the run's loss conditions.
## The run is lost when Gatotkaca dies, or when every pendopo has fallen.

signal lost(reason: String)

const REASON_KING: String = "king"
const REASON_PENDOPO: String = "pendopo"


var _total_pendopos: int = 0
var _destroyed_pendopos: int = 0
var _king_dead: bool = false


func _init(total_pendopos: int = 0) -> void:
	configure(total_pendopos)


func configure(total_pendopos: int) -> void:
	var total: int = maxi(0, total_pendopos)
	# Progress only resets when the objective actually changes size -- a fresh run, or a
	# stage with a different pendopo count. RunController re-syncs this mid-run (to refresh
	# heal targets and minimap markers when a fort falls), and a blanket reset there would
	# wipe the destroyed count, so the last fall would never trigger a loss.
	if total != _total_pendopos:
		_destroyed_pendopos = 0
		_king_dead = false
	_total_pendopos = total


func total_count() -> int:
	return _total_pendopos


func alive_count() -> int:
	return maxi(0, _total_pendopos - _destroyed_pendopos)


func is_king_dead() -> bool:
	return _king_dead


func on_pendopo_destroyed() -> void:
	if _destroyed_pendopos >= _total_pendopos:
		return
	_destroyed_pendopos += 1
	if is_lost():
		lost.emit(REASON_PENDOPO)


func on_king_died() -> void:
	if _king_dead:
		return
	_king_dead = true
	lost.emit(REASON_KING)


func is_lost() -> bool:
	return _king_dead or alive_count() <= 0
