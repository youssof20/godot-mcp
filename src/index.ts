#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { GodotClient } from "./godot-client.js";
import { createMcpServer } from "./mcp-server.js";
import { parseServerMode } from "./modes.js";

async function main(): Promise<void> {
  const mode = parseServerMode(process.argv.slice(2));

  const godotClient = new GodotClient();
  await godotClient.start();

  godotClient.on("connected", () => {
    console.error("[godot-mcp-local] Godot connected");
  });
  godotClient.on("disconnected", () => {
    console.error("[godot-mcp-local] Godot disconnected");
  });

  console.error(
    `[godot-mcp-local] Mode: ${mode} | WebSocket port: ${godotClient.port}`,
  );

  const server = createMcpServer(godotClient, mode);
  const transport = new StdioServerTransport();
  await server.connect(transport);

  const shutdown = async () => {
    await godotClient.stop();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((err) => {
  console.error("[godot-mcp-local] Fatal error:", err);
  process.exit(1);
});
