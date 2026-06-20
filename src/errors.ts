/** Standard error codes for Godot MCP bridge responses. */

export const ErrorCodes = {
  GODOT_NOT_CONNECTED: "GODOT_NOT_CONNECTED",
  TIMEOUT: "TIMEOUT",
  INVALID_PARAMS: "INVALID_PARAMS",
  NOT_FOUND: "NOT_FOUND",
  ALREADY_EXISTS: "ALREADY_EXISTS",
  UNSUPPORTED_NODE_TYPE: "UNSUPPORTED_NODE_TYPE",
  UNSUPPORTED_RESOURCE_TYPE: "UNSUPPORTED_RESOURCE_TYPE",
  GODOT_API_ERROR: "GODOT_API_ERROR",
  SCRIPT_ERROR: "SCRIPT_ERROR",
  SCENE_ERROR: "SCENE_ERROR",
  RUNTIME_NOT_RUNNING: "RUNTIME_NOT_RUNNING",
  PERMISSION_DENIED: "PERMISSION_DENIED",
  DANGEROUS_TOOL_DISABLED: "DANGEROUS_TOOL_DISABLED",
  NOT_IMPLEMENTED: "NOT_IMPLEMENTED",
  INTERNAL_ERROR: "INTERNAL_ERROR",
} as const;

export type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];

export class GodotMcpError extends Error {
  readonly code: ErrorCode;
  readonly suggestion?: string;
  readonly details?: Record<string, unknown>;

  constructor(
    code: ErrorCode,
    message: string,
    options?: { suggestion?: string; details?: Record<string, unknown> },
  ) {
    super(message);
    this.name = "GodotMcpError";
    this.code = code;
    this.suggestion = options?.suggestion;
    this.details = options?.details;
  }
}

export function formatToolError(error: unknown): {
  text: string;
  isError: true;
} {
  if (error instanceof GodotMcpError) {
    const payload = {
      code: error.code,
      message: error.message,
      suggestion: error.suggestion,
      details: error.details,
    };
    return {
      text: JSON.stringify(payload, null, 2),
      isError: true,
    };
  }

  if (error instanceof Error) {
    return {
      text: JSON.stringify(
        {
          code: ErrorCodes.INTERNAL_ERROR,
          message: error.message,
          suggestion: "Check MCP server logs and Godot editor output.",
        },
        null,
        2,
      ),
      isError: true,
    };
  }

  return {
    text: JSON.stringify(
      {
        code: ErrorCodes.INTERNAL_ERROR,
        message: String(error),
        suggestion: "Check MCP server logs and Godot editor output.",
      },
      null,
      2,
    ),
    isError: true,
  };
}
