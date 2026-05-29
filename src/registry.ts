import type { Server } from "@modelcontextprotocol/sdk/server/index.js";
import type { GodotClient } from "./godot-client.js";
import { registerAwarenessTools } from "./tools/awareness.js";
import { registerBlindnessTools } from "./tools/blindness-tools.js";
import { registerAllGodotTools } from "./tools/catalog.js";
import { registerCapabilitiesTool } from "./tools/capabilities.js";
import { registerDescribeSceneTool } from "./tools/describe-scene.js";
import { registerGuardrailTools } from "./tools/guardrails.js";
import { registerSessionTools } from "./tools/session-tools.js";

export function registerTools(
  _server: Server,
  client: GodotClient,
): void {
  registerAllGodotTools(client);
  registerAwarenessTools(client);
  registerBlindnessTools(client);
  registerSessionTools(client);
  registerCapabilitiesTool(client);
  registerDescribeSceneTool(client);
  registerGuardrailTools(client);
}
