import type { Server } from "@modelcontextprotocol/sdk/server/index.js";
import type { Tool } from "@modelcontextprotocol/sdk/types.js";
import { z, type ZodRawShape, type ZodObject, type ZodTypeAny } from "zod";
import type { GodotClient } from "../godot-client.js";
import {
  GodotCommandError,
  GodotConnectionError,
} from "../types.js";
import { checkChatHealth, recordToolCall } from "./session-tracker.js";
import {
  extractScriptPath,
  runPostEditValidation,
} from "./post-edit-validate.js";

const POST_VALIDATE_TOOLS = new Set([
  "edit_script",
  "create_script",
  "update_property",
]);

export interface ToolDefinition<T extends ZodRawShape> {
  name: string;
  description: string;
  schema: ZodObject<T>;
  handler: (
    client: GodotClient,
    args: z.infer<ZodObject<T>>,
  ) => Promise<unknown>;
  /** Override default JSON text formatting (e.g. capture_frames images). */
  formatResult?: (result: unknown) => { content: McpContentBlock[] };
}

export type McpContentBlock =
  | { type: "text"; text: string }
  | { type: "image"; data: string; mimeType: string };

function fieldDescription(field: ZodTypeAny): string | undefined {
  return field.description;
}

function isFieldOptional(field: ZodTypeAny): boolean {
  return field instanceof z.ZodOptional || field instanceof z.ZodDefault;
}

/** Convert a Zod field (including Default/Optional wrappers) to JSON Schema fragment. */
function zodFieldToJson(field: ZodTypeAny): Record<string, unknown> {
  if (field instanceof z.ZodDefault) {
    const inner = zodFieldToJson(field._def.innerType as ZodTypeAny);
    const defaultValue = field._def.defaultValue();
    return {
      ...inner,
      default:
        typeof defaultValue === "function" ? defaultValue() : defaultValue,
      ...(fieldDescription(field) ? { description: fieldDescription(field) } : {}),
    };
  }

  if (field instanceof z.ZodOptional) {
    const inner = zodFieldToJson(field._def.innerType as ZodTypeAny);
    return {
      ...inner,
      ...(fieldDescription(field) ? { description: fieldDescription(field) } : {}),
    };
  }

  let base: Record<string, unknown> = {};

  if (field instanceof z.ZodString) {
    base = { type: "string" };
  } else if (field instanceof z.ZodNumber) {
    base = { type: "number" };
  } else if (field instanceof z.ZodBoolean) {
    base = { type: "boolean" };
  } else if (field instanceof z.ZodEnum) {
    base = { type: "string", enum: field._def.values };
  } else if (field instanceof z.ZodArray) {
    base = {
      type: "array",
      items: zodFieldToJson(field._def.type as ZodTypeAny),
    };
  } else if (field instanceof z.ZodRecord) {
    base = { type: "object", additionalProperties: true };
  } else if (field instanceof z.ZodUnion) {
    const options = field._def.options as ZodTypeAny[];
    if (options.length > 0) {
      base = zodFieldToJson(options[0]);
    }
  } else if (field instanceof z.ZodObject) {
    const shape = field.shape;
    const properties: Record<string, Record<string, unknown>> = {};
    const required: string[] = [];
    for (const [key, sub] of Object.entries(shape)) {
      properties[key] = zodFieldToJson(sub as ZodTypeAny);
      if (!isFieldOptional(sub as ZodTypeAny)) {
        required.push(key);
      }
    }
    base = {
      type: "object",
      properties,
      ...(required.length > 0 ? { required } : {}),
    };
  } else {
    base = {};
  }

  const desc = fieldDescription(field);
  if (desc) {
    base.description = desc;
  }
  return base;
}

export function zodToJsonSchema(schema: ZodObject<ZodRawShape>): Tool["inputSchema"] {
  const shape = schema.shape;
  const properties: Record<string, object> = {};
  const required: string[] = [];

  for (const [key, field] of Object.entries(shape)) {
    const zodField = field as ZodTypeAny;
    properties[key] = zodFieldToJson(zodField) as object;
    if (!isFieldOptional(zodField)) {
      required.push(key);
    }
  }

  return {
    type: "object",
    properties,
    ...(required.length > 0 ? { required } : {}),
  };
}

export function formatToolContent(result: unknown): {
  content: McpContentBlock[];
} {
  const content: McpContentBlock[] = [];

  if (result && typeof result === "object") {
    const r = result as Record<string, unknown>;
    if (typeof r.image_base64 === "string") {
      content.push({
        type: "image",
        data: r.image_base64,
        mimeType: "image/png",
      });
    }
    if (typeof r.diff_image_base64 === "string") {
      content.push({
        type: "image",
        data: r.diff_image_base64,
        mimeType: "image/png",
      });
    }
  }

  content.push({
    type: "text",
    text: JSON.stringify(result, null, 2),
  });

  return { content };
}

/** MCP image blocks for capture_frames (max 5 images + text notes). */
export function formatCaptureFramesContent(result: unknown): {
  content: McpContentBlock[];
} {
  const content: McpContentBlock[] = [];
  if (!result || typeof result !== "object") {
    return formatToolContent(result);
  }

  const r = result as Record<string, unknown>;
  const frames = Array.isArray(r.frames)
    ? r.frames.filter((f): f is string => typeof f === "string")
    : [];

  const displayCount = Math.min(frames.length, 5);
  for (let i = 0; i < displayCount; i++) {
    content.push({
      type: "image",
      data: frames[i]!,
      mimeType: "image/png",
    });
    content.push({
      type: "text",
      text: `Frame ${i + 1} of ${frames.length}`,
    });
  }

  if (frames.length > 5) {
    const savePath =
      typeof r.save_path === "string" ? r.save_path : undefined;
    content.push({
      type: "text",
      text: savePath
        ? `Showing first 5 of ${frames.length} frames. Remaining frames are available on disk at ${savePath}.`
        : `Showing first 5 of ${frames.length} frames. Remaining frame data is in the JSON below.`,
    });
  }

  content.push({
    type: "text",
    text: JSON.stringify(result, null, 2),
  });

  return { content };
}

export function formatToolError(message: string): {
  content: Array<{ type: "text"; text: string }>;
  isError: true;
} {
  return {
    content: [{ type: "text", text: message }],
    isError: true,
  };
}

export async function callGodot(
  client: GodotClient,
  method: string,
  params: Record<string, unknown> = {},
): Promise<unknown> {
  return client.send(method, params);
}

function appendChatHealthWarning(
  response: { content: McpContentBlock[]; isError?: boolean },
): { content: McpContentBlock[]; isError?: boolean } {
  const health = checkChatHealth();
  if (health.healthy) return response;
  const prefix = `[Session health warning] ${health.plain_english}\n\n`;
  const first = response.content[0];
  if (first?.type === "text") {
    return {
      ...response,
      content: [{ type: "text", text: prefix + first.text }, ...response.content.slice(1)],
    };
  }
  return {
    ...response,
    content: [{ type: "text", text: prefix.trim() }, ...response.content],
  };
}

export function wrapHandler<T extends ZodRawShape>(
  client: GodotClient,
  def: ToolDefinition<T>,
): (args: z.infer<ZodObject<T>>) => Promise<{
  content: McpContentBlock[];
  isError?: boolean;
}> {
  return async (rawArgs) => {
    const argsRecord = (rawArgs ?? {}) as Record<string, unknown>;
    try {
      const args = def.schema.parse(rawArgs ?? {}) as z.infer<ZodObject<T>>;
      const result = await def.handler(client, args);

      let merged: unknown = result;
      if (POST_VALIDATE_TOOLS.has(def.name)) {
        const scriptPath = extractScriptPath(
          def.name,
          argsRecord,
          result,
        );
        const nodePath =
          typeof argsRecord.node_path === "string"
            ? argsRecord.node_path
            : undefined;
        const validation = await runPostEditValidation(
          client,
          scriptPath,
        );
        merged = {
          ...(result && typeof result === "object"
            ? (result as Record<string, unknown>)
            : { result }),
          post_edit_validation: validation,
          ...(nodePath ? { edited_node: nodePath } : {}),
        };
      }

      recordToolCall(def.name, argsRecord, true);

      let response: { content: McpContentBlock[]; isError?: boolean };
      if (def.formatResult) {
        response = def.formatResult(merged);
      } else {
        response = formatToolContent(merged);
      }
      return appendChatHealthWarning(response);
    } catch (err) {
      const errMsg =
        err instanceof GodotCommandError
          ? err.message
          : err instanceof Error
            ? err.message
            : String(err);
      recordToolCall(def.name, argsRecord, false, errMsg);

      let response: { content: McpContentBlock[]; isError?: boolean };
      if (err instanceof z.ZodError) {
        response = formatToolError(
          `Invalid parameters: ${err.errors.map((e) => `${e.path.join(".")}: ${e.message}`).join("; ")}`,
        );
      } else if (err instanceof GodotConnectionError) {
        response = formatToolError(err.message);
      } else if (err instanceof GodotCommandError) {
        response = formatToolError(err.message);
      } else if (err instanceof Error) {
        response = formatToolError(err.message);
      } else {
        response = formatToolError(String(err));
      }
      return appendChatHealthWarning(response);
    }
  };
}

const toolRegistry: Array<{
  def: ToolDefinition<ZodRawShape>;
  handler: ReturnType<typeof wrapHandler>;
  mcpTool: Tool;
}> = [];

export function registerTool<T extends ZodRawShape>(
  client: GodotClient,
  def: ToolDefinition<T>,
): void {
  const handler = wrapHandler(client, def as ToolDefinition<ZodRawShape>);
  toolRegistry.push({
    def: def as ToolDefinition<ZodRawShape>,
    handler: handler as ReturnType<typeof wrapHandler>,
    mcpTool: {
      name: def.name,
      description: def.description,
      inputSchema: zodToJsonSchema(def.schema),
    },
  });
}

export function getRegisteredTools(): Tool[] {
  return toolRegistry.map((t) => t.mcpTool);
}

export function getToolRegistryEntries(): Array<{
  name: string;
  description: string;
}> {
  return toolRegistry.map((t) => ({
    name: t.def.name,
    description: t.def.description,
  }));
}

export function getToolHandler(
  name: string,
): ReturnType<typeof wrapHandler> | undefined {
  return toolRegistry.find((t) => t.def.name === name)?.handler;
}

export function clearToolRegistry(): void {
  toolRegistry.length = 0;
}

export function setupMcpHandlers(server: Server, client: GodotClient): void {
  void server;
  void client;
}
