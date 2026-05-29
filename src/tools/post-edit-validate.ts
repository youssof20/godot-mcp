import type { GodotClient } from "../godot-client.js";
import { callGodot } from "./helpers.js";
import { scanGodot3Patterns } from "./blindness-tools.js";

export interface PostEditValidation {
  script_path?: string;
  validate_script?: unknown;
  validate_script_error?: string;
  godot4_api_patterns?: unknown;
  editor_errors?: unknown;
  editor_errors_error?: string;
  plain_english: string;
}

export async function runPostEditValidation(
  client: GodotClient,
  scriptPath?: string,
): Promise<PostEditValidation> {
  const out: PostEditValidation = { plain_english: "" };
  const sentences: string[] = [];

  if (scriptPath) {
    out.script_path = scriptPath;
    try {
      out.validate_script = await callGodot(client, "validate_script", {
        path: scriptPath,
      });
      const vs = out.validate_script as { valid?: boolean; errors?: unknown[] };
      if (vs.valid === false) {
        sentences.push(
          `validate_script reports syntax errors in ${scriptPath} — fix before continuing.`,
        );
      } else {
        sentences.push(`validate_script: ${scriptPath} syntax OK.`);
      }
    } catch (err) {
      out.validate_script_error =
        err instanceof Error ? err.message : String(err);
      sentences.push(`validate_script failed: ${out.validate_script_error}`);
    }

    try {
      const read = (await callGodot(client, "read_script", {
        path: scriptPath,
      })) as { content?: string };
      const content = read.content ?? "";
      const findings = scanGodot3Patterns(content);
      out.godot4_api_patterns = { findings, count: findings.length };
      if (findings.length > 0) {
        sentences.push(
          `validate_godot4_api: ${findings.length} Godot 3 pattern(s) in ${scriptPath}.`,
        );
      } else {
        sentences.push(`validate_godot4_api: no Godot 3 patterns in ${scriptPath}.`);
      }
    } catch (err) {
      sentences.push(
        `validate_godot4_api scan failed: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }

  try {
    out.editor_errors = await callGodot(client, "get_editor_errors", {
      max_lines: 25,
    });
    const errResult = out.editor_errors as { errors?: unknown[] };
    const errList = Array.isArray(errResult?.errors) ? errResult.errors : [];
    if (errList.length > 0) {
      sentences.push(
        `Godot Output panel shows ${errList.length} error line(s) after this edit — review editor_errors.`,
      );
    } else {
      sentences.push("Godot Output panel: no new error lines detected.");
    }
  } catch (err) {
    out.editor_errors_error = err instanceof Error ? err.message : String(err);
    sentences.push(`get_editor_errors failed: ${out.editor_errors_error}`);
  }

  out.plain_english =
    sentences.length > 0
      ? sentences.join(" ")
      : "Post-edit validation completed with no issues noted.";

  return out;
}

/** Extract script path from edit/create tool args or result. */
export function extractScriptPath(
  toolName: string,
  args: Record<string, unknown>,
  result: unknown,
): string | undefined {
  if (typeof args.path === "string" && args.path.endsWith(".gd")) {
    return args.path;
  }
  if (result && typeof result === "object") {
    const r = result as Record<string, unknown>;
    if (typeof r.path === "string") return r.path;
    if (typeof r.script_path === "string") return r.script_path;
  }
  if (toolName === "create_script" && typeof args.path === "string") {
    return args.path;
  }
  return undefined;
}
