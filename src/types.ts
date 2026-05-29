export interface JsonRpcRequest {
  jsonrpc: "2.0";
  id: string | number;
  method: string;
  params?: Record<string, unknown>;
}

export interface GodotErrorData {
  suggestion?: string;
  path?: string;
  open_scenes?: string[];
  [key: string]: unknown;
}

export interface GodotError {
  code: number;
  message: string;
  data?: GodotErrorData;
}

export interface JsonRpcResponse {
  jsonrpc: "2.0";
  id?: string | number | null;
  result?: unknown;
  error?: GodotError;
  method?: string;
  params?: Record<string, unknown>;
}

export class GodotConnectionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GodotConnectionError";
  }
}

export class GodotCommandError extends Error {
  code: number;
  data?: GodotErrorData;

  constructor(error: GodotError) {
    const plain =
      typeof error.data?.plain_english === "string"
        ? error.data.plain_english
        : undefined;

    if (error.code === -32009 && plain) {
      super(plain);
    } else if (plain) {
      const suggestion = error.data?.suggestion
        ? ` ${error.data.suggestion}`
        : "";
      super(`${plain}${suggestion}`);
    } else {
      const suggestion = error.data?.suggestion
        ? ` Suggestion: ${error.data.suggestion}`
        : "";
      super(`[${error.code}] ${error.message}${suggestion}`);
    }
    this.name = "GodotCommandError";
    this.code = error.code;
    this.data = error.data;
  }
}

const VECTOR2_RE = /^Vector2\s*\(\s*([^,]+)\s*,\s*([^)]+)\s*\)$/i;
const VECTOR3_RE = /^Vector3\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\s*\)$/i;
const COLOR_RE = /^Color\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^,)]+)(?:\s*,\s*([^)]+))?\s*\)$/i;
const HEX_COLOR_RE = /^#([0-9a-fA-F]{3,8})$/;

/**
 * Parse string values into JSON-serializable forms Godot's PropertyParser accepts.
 */
export function parseGodotValue(input: string): unknown {
  const trimmed = input.trim();

  if (trimmed === "true") return true;
  if (trimmed === "false") return false;

  if (/^-?\d+$/.test(trimmed)) {
    return parseInt(trimmed, 10);
  }

  if (/^-?\d+\.\d+$/.test(trimmed) || /^-?\d+\.$/.test(trimmed)) {
    return parseFloat(trimmed);
  }

  const v2 = trimmed.match(VECTOR2_RE);
  if (v2) {
    return { x: parseFloat(v2[1]), y: parseFloat(v2[2]) };
  }

  const v3 = trimmed.match(VECTOR3_RE);
  if (v3) {
    return {
      x: parseFloat(v3[1]),
      y: parseFloat(v3[2]),
      z: parseFloat(v3[3]),
    };
  }

  if (HEX_COLOR_RE.test(trimmed)) {
    return trimmed;
  }

  const color = trimmed.match(COLOR_RE);
  if (color) {
    const c: Record<string, number> = {
      r: parseFloat(color[1]),
      g: parseFloat(color[2]),
      b: parseFloat(color[3]),
    };
    if (color[4] !== undefined) {
      c.a = parseFloat(color[4]);
    }
    return c;
  }

  return input;
}
