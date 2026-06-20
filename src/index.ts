#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { GodotClient } from "./godotClient.js";
import { registerAllTools } from "./toolRegistry.js";
import { getGodotPort } from "./schemas.js";

const SERVER_NAME = "godot-mcp-personal";
const SERVER_VERSION = "0.1.0";

async function main(): Promise<void> {
  const port = getGodotPort();
  console.error(`[godot-mcp] Starting ${SERVER_NAME} v${SERVER_VERSION} (port ${port})`);

  const godotClient = new GodotClient({ port });

  // Attempt initial connection in background; tools report GODOT_NOT_CONNECTED if editor is down.
  godotClient.start().catch((error) => {
    console.error(
      `[godot-mcp] Initial Godot connection failed: ${error instanceof Error ? error.message : String(error)}`,
    );
  });

  const server = new McpServer({
    name: SERVER_NAME,
    version: SERVER_VERSION,
  });

  registerAllTools(server, godotClient);

  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[godot-mcp] MCP stdio transport ready");

  const shutdown = async () => {
    await godotClient.stop();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((error) => {
  console.error("[godot-mcp] Fatal error:", error);
  process.exit(1);
});
