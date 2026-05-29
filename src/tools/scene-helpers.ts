import type { GodotClient } from "../godot-client.js";
import { callGodot } from "./helpers.js";

/** Prefer an explicit scene path, then project main scene, then editor "current". */
export async function resolvePlaySceneMode(
  client: GodotClient,
  scenePath?: string,
): Promise<{ mode: string; reason: string }> {
  if (scenePath?.trim()) {
    return { mode: scenePath.trim(), reason: "explicit scene_path parameter" };
  }

  const info = (await callGodot(client, "get_project_info", {})) as {
    main_scene?: string;
  };
  const main = typeof info.main_scene === "string" ? info.main_scene.trim() : "";
  if (main) {
    return { mode: main, reason: "project main_scene (avoids empty editor / select-main-scene dialog)" };
  }

  return {
    mode: "current",
    reason: "no main_scene set; requires an open scene tab in the editor",
  };
}

/** Open main scene in the editor when nothing is active (addon auto_open also handles get_scene_tree). */
export async function ensureEditorSceneOpen(client: GodotClient): Promise<void> {
  const info = (await callGodot(client, "get_project_info", {})) as {
    main_scene?: string;
  };
  const main = typeof info.main_scene === "string" ? info.main_scene.trim() : "";
  if (!main) return;

  try {
    await callGodot(client, "open_scene", { path: main });
  } catch {
    // open_scene may fail if already open; get_scene_tree auto_open is fallback
  }
}
