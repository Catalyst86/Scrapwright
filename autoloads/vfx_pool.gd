extends Node

# ============================================================
# VFXPool — reusable pool for short-lived Line2D / Polygon2D
# nodes spawned by orbitals, bark attacks, and hit bursts.
# (Audit FP-6)
#
# Usage:
#   var bolt: Line2D = VFXPool.acquire_line2d(arena)
#   bolt.width = 2.0
#   bolt.default_color = Color.YELLOW
#   bolt.add_point(a)
#   bolt.add_point(b)
#   VFXPool.release_line2d(bolt, 0.15)  # fade over 0.15s, then return
#
# Nodes are owned by VFXPool and reparented under the caller's
# tree on acquire. They are clear/reset on release so the next
# caller starts fresh. Pool is capped (see POOL_MAX) so it
# cannot grow without bound under pathological load.
# ============================================================

const POOL_MAX := 64

var _line_pool: Array = []
var _polygon_pool: Array = []


func acquire_line2d(parent: Node) -> Line2D:
	var node: Line2D
	if _line_pool.is_empty():
		node = Line2D.new()
	else:
		node = _line_pool.pop_back()
	_reset_line(node)
	if parent and is_instance_valid(parent):
		parent.add_child(node)
	return node


func release_line2d(node: Line2D, fade_duration: float = 0.0) -> void:
	if not is_instance_valid(node):
		return
	if fade_duration <= 0.0:
		_return_line(node)
		return
	var tw = node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, fade_duration)
	tw.tween_callback(Callable(self, "_return_line").bind(node))


func acquire_polygon2d(parent: Node) -> Polygon2D:
	var node: Polygon2D
	if _polygon_pool.is_empty():
		node = Polygon2D.new()
	else:
		node = _polygon_pool.pop_back()
	_reset_polygon(node)
	if parent and is_instance_valid(parent):
		parent.add_child(node)
	return node


func release_polygon2d(node: Polygon2D, fade_duration: float = 0.0) -> void:
	if not is_instance_valid(node):
		return
	if fade_duration <= 0.0:
		_return_polygon(node)
		return
	var tw = node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, fade_duration)
	tw.tween_callback(Callable(self, "_return_polygon").bind(node))


# --- internal -------------------------------------------------

func _return_line(node: Line2D) -> void:
	if not is_instance_valid(node):
		return
	# Detach from current parent, reset, and cache.
	if node.get_parent():
		node.get_parent().remove_child(node)
	_reset_line(node)
	if _line_pool.size() < POOL_MAX:
		_line_pool.append(node)
	else:
		node.queue_free()


func _return_polygon(node: Polygon2D) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent():
		node.get_parent().remove_child(node)
	_reset_polygon(node)
	if _polygon_pool.size() < POOL_MAX:
		_polygon_pool.append(node)
	else:
		node.queue_free()


func _reset_line(node: Line2D) -> void:
	node.clear_points()
	node.width = 1.0
	node.default_color = Color.WHITE
	node.modulate = Color.WHITE
	node.position = Vector2.ZERO
	node.rotation = 0.0
	node.scale = Vector2.ONE
	node.z_index = 0
	node.z_as_relative = true


func _reset_polygon(node: Polygon2D) -> void:
	node.polygon = PackedVector2Array()
	node.color = Color.WHITE
	node.modulate = Color.WHITE
	node.position = Vector2.ZERO
	node.rotation = 0.0
	node.scale = Vector2.ONE
	node.z_index = 0
	node.z_as_relative = true
