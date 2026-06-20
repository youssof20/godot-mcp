## Parse JSON tool params into Godot Variants for property assignment.
## Godot 4.4+ assumption: Variant property assignment on Node.set().
class_name MCPTypeParser
extends RefCounted

static func is_dictionary(value: Variant) -> bool:
	return typeof(value) == TYPE_DICTIONARY


static func parse_value(value: Variant) -> Variant:
	if value == null:
		return null
	match typeof(value):
		TYPE_DICTIONARY:
			var d: Dictionary = value
			if d.has("x") and d.has("y"):
				if d.has("z"):
					return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
				if d.has("w"):
					return Vector4(float(d["x"]), float(d["y"]), float(d["z"]), float(d["w"]))
				return Vector2(float(d["x"]), float(d["y"]))
			if d.has("r") and d.has("g") and d.has("b"):
				return Color(
					float(d.get("r", 0)),
					float(d.get("g", 0)),
					float(d.get("b", 0)),
					float(d.get("a", 1))
				)
			return d
		TYPE_ARRAY:
			var arr: Array = value
			var out: Array = []
			for item in arr:
				out.append(parse_value(item))
			return out
		_:
			return value


static func coerce_for_property(node: Node, property: String, value: Variant) -> Variant:
	var parsed := parse_value(value)
	if typeof(parsed) == TYPE_STRING:
		var s := str(parsed)
		if s.begins_with("res://") or s.begins_with("uid://"):
			var resolved := MCPPathUtils.resolve_readable_path(s)
			var loaded: Resource = load(resolved)
			if loaded != null:
				return loaded
	return parsed


static func anchor_preset_from_param(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	var name := str(value).strip_edges().to_upper()
	match name:
		"TOP_LEFT", "PRESET_TOP_LEFT":
			return Control.PRESET_TOP_LEFT
		"TOP_RIGHT", "PRESET_TOP_RIGHT":
			return Control.PRESET_TOP_RIGHT
		"BOTTOM_LEFT", "PRESET_BOTTOM_LEFT":
			return Control.PRESET_BOTTOM_LEFT
		"BOTTOM_RIGHT", "PRESET_BOTTOM_RIGHT":
			return Control.PRESET_BOTTOM_RIGHT
		"CENTER_LEFT", "PRESET_CENTER_LEFT":
			return Control.PRESET_CENTER_LEFT
		"CENTER_TOP", "PRESET_CENTER_TOP":
			return Control.PRESET_CENTER_TOP
		"CENTER_RIGHT", "PRESET_CENTER_RIGHT":
			return Control.PRESET_CENTER_RIGHT
		"CENTER_BOTTOM", "PRESET_CENTER_BOTTOM":
			return Control.PRESET_CENTER_BOTTOM
		"CENTER", "PRESET_CENTER":
			return Control.PRESET_CENTER
		"LEFT_WIDE", "PRESET_LEFT_WIDE":
			return Control.PRESET_LEFT_WIDE
		"TOP_WIDE", "PRESET_TOP_WIDE":
			return Control.PRESET_TOP_WIDE
		"RIGHT_WIDE", "PRESET_RIGHT_WIDE":
			return Control.PRESET_RIGHT_WIDE
		"BOTTOM_WIDE", "PRESET_BOTTOM_WIDE":
			return Control.PRESET_BOTTOM_WIDE
		"VCENTER_WIDE", "PRESET_VCENTER_WIDE":
			return Control.PRESET_VCENTER_WIDE
		"HCENTER_WIDE", "PRESET_HCENTER_WIDE":
			return Control.PRESET_HCENTER_WIDE
		"FULL_RECT", "PRESET_FULL_RECT":
			return Control.PRESET_FULL_RECT
		_:
			return -1
