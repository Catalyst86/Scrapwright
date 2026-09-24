extends RefCounted
## Keyboard / controller focus helpers for the code-built UIs.
##
## Buttons are focusable by default, but nothing gave them focus when a screen or
## popup opened, so a controller (or keyboard-only player) could not press
## anything. Usage:
##   const UIFocus = preload("res://scripts/ui_focus.gd")
##   UIFocus.focus_first(panel)            # when a screen / popup opens
##   UIFocus.trap([name_edit, ok, cancel])  # keep D-pad focus inside a modal
##   var prev := UIFocus.capture(get_viewport()) ... UIFocus.restore(prev)


## Focuses the first visible, enabled control under `root` that keyboard /
## controller navigation can reach (depth-first, child order) and returns it, or
## null if there is none.
static func focus_first(root: Node) -> Control:
	var ctl := first_focusable(root)
	if ctl:
		ctl.grab_focus()
	return ctl


static func first_focusable(root: Node) -> Control:
	if root == null or not is_instance_valid(root) or root.is_queued_for_deletion():
		return null
	for child in root.get_children():
		if child.is_queued_for_deletion():
			continue  # Replaced this frame (e.g. rebuilt cards)
		if child is Control:
			var ctl := child as Control
			if not ctl.is_visible_in_tree():
				continue
			# FOCUS_ALL only: RichTextLabel defaults to FOCUS_ACCESSIBILITY (screen
			# readers), and the override honours focus_behavior_recursive.
			if ctl.get_focus_mode_with_override() == Control.FOCUS_ALL \
					and not (ctl is BaseButton and (ctl as BaseButton).disabled):
				return ctl
		var deeper := first_focusable(child)
		if deeper:
			return deeper
	return null


## Remembers which control has focus (and whether its focus ring is hidden, as it
## is after a mouse click), so a popup can hand focus back when it closes.
static func capture(viewport: Viewport) -> Dictionary:
	var ctl := viewport.gui_get_focus_owner()
	return {"control": ctl, "hidden": ctl != null and not ctl.has_focus(true)}


## Gives focus back to a `capture()`d control if it can still take it. Returns
## false when it can't (freed, hidden or unfocusable), so the caller can pick
## another target.
static func restore(snapshot: Dictionary) -> bool:
	var ctl = snapshot.get("control")
	if not is_instance_valid(ctl) or not ctl.is_inside_tree() or not ctl.is_visible_in_tree():
		return false
	if ctl.get_focus_mode_with_override() == Control.FOCUS_NONE:
		return false
	ctl.grab_focus(snapshot.get("hidden", false))
	return true


## Makes D-pad / stick / Tab navigation cycle through `controls` only, so focus
## can't escape a modal popup to buttons behind it. Up/left go to the previous
## control, down/right to the next, wrapping around. Call once all the controls
## are inside the scene tree.
static func trap(controls: Array) -> void:
	var ring: Array = controls.filter(func(c): return c is Control and is_instance_valid(c))
	var n := ring.size()
	for i in n:
		var ctl: Control = ring[i]
		var prev: NodePath = ctl.get_path_to(ring[(i - 1 + n) % n])
		var next: NodePath = ctl.get_path_to(ring[(i + 1) % n])
		ctl.set_focus_neighbor(SIDE_LEFT, prev)
		ctl.set_focus_neighbor(SIDE_TOP, prev)
		ctl.set_focus_neighbor(SIDE_RIGHT, next)
		ctl.set_focus_neighbor(SIDE_BOTTOM, next)
		ctl.focus_previous = prev
		ctl.focus_next = next
