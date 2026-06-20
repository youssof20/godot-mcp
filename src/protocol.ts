/** Wire protocol types shared between TypeScript MCP server and Godot plugin. */

export interface GodotRequest {
  id: string;
  method: string;
  params: Record<string, unknown>;
}

export interface GodotSuccessResponse {
  id: string;
  ok: true;
  result: unknown;
}

export interface GodotErrorPayload {
  code: string;
  message: string;
  suggestion?: string;
  details?: Record<string, unknown>;
}

export interface GodotErrorResponse {
  id: string;
  ok: false;
  error: GodotErrorPayload;
}

export type GodotResponse = GodotSuccessResponse | GodotErrorResponse;

export function isGodotErrorResponse(
  response: GodotResponse,
): response is GodotErrorResponse {
  return response.ok === false;
}
