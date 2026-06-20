import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { formatToolError } from "../errors.js";
import { emptyParamsSchema } from "../schemas.js";
import { IMPLEMENTED_TOOLS } from "./constants.js";

function jsonResult(data: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
  };
}

export function registerServerTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  if (enabled.has("godot_ping")) {
    server.tool(
      "godot_ping",
      "Ping the Godot editor plugin to verify the MCP bridge is alive.",
      emptyParamsSchema.shape,
      async () => {
        try {
          const result = await client.callTool("godot_ping", {});
          return jsonResult(result);
        } catch (error) {
          const formatted = formatToolError(error);
          return {
            content: [{ type: "text", text: formatted.text }],
            isError: true,
          };
        }
      },
    );
  }

  if (enabled.has("get_connection_status")) {
    server.tool(
      "get_connection_status",
      "Get MCP server ↔ Godot WebSocket connection status from both sides.",
      emptyParamsSchema.shape,
      async () => {
        try {
          const tsStatus = client.getConnectionStatus();
          let godotStatus: unknown = null;
          if (client.isConnected()) {
            try {
              godotStatus = await client.callTool("get_connection_status", {});
            } catch {
              godotStatus = { reachable: false };
            }
          }
          return jsonResult({
            typescript: tsStatus,
            godot: godotStatus,
          });
        } catch (error) {
          const formatted = formatToolError(error);
          return {
            content: [{ type: "text", text: formatted.text }],
            isError: true,
          };
        }
      },
    );
  }

  if (enabled.has("list_available_tools")) {
    server.tool(
      "list_available_tools",
      "List tools implemented on the Godot plugin side (working end-to-end).",
      emptyParamsSchema.shape,
      async () => {
        try {
          const result = await client.callTool("list_available_tools", {});
          return jsonResult({
            ...(typeof result === "object" && result !== null
              ? (result as Record<string, unknown>)
              : { tools: result }),
            typescript_registered: [...IMPLEMENTED_TOOLS],
          });
        } catch (error) {
          const formatted = formatToolError(error);
          return {
            content: [{ type: "text", text: formatted.text }],
            isError: true,
          };
        }
      },
    );
  }
}
