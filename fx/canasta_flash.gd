## Flash overlay full-screen de corta duración (Tokens.DUR_FLASH).
## Pensado para el momento "¡Canasta!": destello dorado breve sobre el HUD.
##
## Uso:
##   `CanastaFlash.spawn(get_tree().root, Tokens.TRIM_GOLD)`
class_name CanastaFlash
extends ColorRect


static func spawn(parent: Node, tint: Color = Tokens.TRIM_GOLD) -> void:
	if parent == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = Tokens.Z_POPUP
	parent.add_child(layer)

	var rect: ColorRect = ColorRect.new()
	rect.color = Color(tint.r, tint.g, tint.b, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)

	var t: Tween = parent.get_tree().create_tween()
	t.tween_property(rect, "color:a", 0.55, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(rect, "color:a", 0.0, Tokens.DUR_FLASH).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.finished.connect(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	)
