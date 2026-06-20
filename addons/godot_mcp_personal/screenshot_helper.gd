## Capture Viewport/SubViewport images as PNG base64 for MCP tools.
## Godot 4.4+ API: Viewport.get_texture().get_image(), Image.save_png_to_buffer()
class_name MCPScreenshotHelper
extends RefCounted

const MCP_CAPTURE_DIR := "user://mcp_captures"


static func ensure_capture_dir() -> String:
	if not DirAccess.dir_exists_absolute(MCP_CAPTURE_DIR):
		DirAccess.make_dir_recursive_absolute(MCP_CAPTURE_DIR)
	return MCP_CAPTURE_DIR


static func capture_subviewport(viewport: SubViewport) -> Image:
	if viewport == null:
		return null
	# Godot 4.4+ API: SubViewport.render_target_update_mode, RenderingServer.force_draw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for _i in range(3):
		RenderingServer.force_draw()
		OS.delay_msec(16)
	var tex := viewport.get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	return img


static func capture_viewport(viewport: Viewport) -> Image:
	if viewport == null:
		return null
	RenderingServer.force_draw()
	var tex := viewport.get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	return img


static func capture_runtime_root(runtime_root: Node) -> Image:
	if runtime_root == null:
		return null
	return capture_viewport(runtime_root.get_viewport())


static func image_to_png_base64(img: Image) -> String:
	if img == null:
		return ""
	var bytes: PackedByteArray = img.save_png_to_buffer()
	return Marshalls.raw_to_base64(bytes)


static func save_image_png(img: Image, filename: String) -> String:
	ensure_capture_dir()
	var path := MCP_CAPTURE_DIR.path_join(filename)
	var err := img.save_png(path)
	if err != OK:
		return ""
	return path


static func load_image_from_path(path: String) -> Image:
	var normalized := MCPPathUtils.normalize_storage_path(path.strip_edges())
	var img := Image.new()
	# Godot 4.4+ API: Image.load accepts res:// and user:// directly.
	if img.load(normalized) == OK:
		return img
	var global_path := MCPPathUtils.globalize_storage_path(normalized)
	if global_path != normalized and img.load(global_path) == OK:
		return img
	return null


static func compare_images(a: Image, b: Image) -> Dictionary:
	if a == null or b == null:
		return {"match": false, "reason": "missing_image"}
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return {
			"match": false,
			"reason": "size_mismatch",
			"width_a": a.get_width(),
			"height_a": a.get_height(),
			"width_b": b.get_width(),
			"height_b": b.get_height(),
		}
	var total := a.get_width() * a.get_height()
	var diff := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				diff += 1
	return {
		"match": diff == 0,
		"diff_pixels": diff,
		"total_pixels": total,
		"diff_ratio": float(diff) / float(total) if total > 0 else 0.0,
	}
