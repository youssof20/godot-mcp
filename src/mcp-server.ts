import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import type { GodotClient } from "./godot-client.js";
import {
  isToolEnabledInMode,
  type ServerMode,
} from "./modes.js";
import { registerTools } from "./registry.js";
import {
  clearToolRegistry,
  getRegisteredTools,
  getToolHandler,
} from "./tools/helpers.js";
import { clearToolCategories } from "./tools/spec.js";

export function createMcpServer(
  godotClient: GodotClient,
  mode: ServerMode,
): Server {
  clearToolRegistry();
  clearToolCategories();

  const server = new Server(
    { name: "godot-mcp-local", version: "2.0.0" },
    { capabilities: { tools: {} } },
  );

  registerTools(server, godotClient);

  server.setRequestHandler(ListToolsRequestSchema, async () => {
    const tools = getRegisteredTools().filter((t) =>
      isToolEnabledInMode(t.name, mode),
    );
    return { tools };
  });

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const name = request.params.name;

    if (!isToolEnabledInMode(name, mode)) {
      return {
        content: [
          {
            type: "text",
            text: `Tool '${name}' is not available in ${mode} mode. Use full mode (no flags) for all tools.`,
          },
        ],
        isError: true,
      };
    }

    const handler = getToolHandler(name);
    if (!handler) {
      return {
        content: [{ type: "text", text: `Unknown tool: ${name}` }],
        isError: true,
      };
    }

    const args = (request.params.arguments ?? {}) as Record<string, unknown>;
    return handler(args);
  });

  return server;
}
