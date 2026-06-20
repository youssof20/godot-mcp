import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { z } from "zod";
import type { GodotClient } from "../godotClient.js";
import { formatToolError } from "../errors.js";

export function jsonToolResult(data: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
  };
}

export function registerGodotTool(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
  name: string,
  description: string,
  shape: z.ZodRawShape,
): void {
  if (!enabled.has(name)) {
    return;
  }

  server.tool(name, description, shape, async (params: Record<string, unknown>) => {
    try {
      const result = await client.callTool(name, params);
      return jsonToolResult(result);
    } catch (error) {
      const formatted = formatToolError(error);
      return {
        content: [{ type: "text", text: formatted.text }],
        isError: true,
      };
    }
  });
}
