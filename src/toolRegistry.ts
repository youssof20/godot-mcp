import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "./godotClient.js";
import { registerServerTools } from "./tools/server.js";
import { registerProjectTools } from "./tools/project.js";
import { registerSceneTools } from "./tools/scene.js";
import { registerNodeTools } from "./tools/node.js";
import { registerScriptTools } from "./tools/script.js";
import { registerEditorTools } from "./tools/editor.js";
import { registerResourceTools } from "./tools/resource.js";
import { registerBatchRefactorTools } from "./tools/batchRefactor.js";
import { registerRuntimeTools } from "./tools/runtime.js";
import { registerInputTools } from "./tools/input.js";
import { registerTestingQaTools } from "./tools/testingQa.js";
import { registerAnimationTools } from "./tools/animation.js";
import { registerAnimationTreeTools } from "./tools/animationTree.js";
import { registerTilemapTools } from "./tools/tilemap.js";
import {
  IMPLEMENTED_TOOLS,
  MINIMAL_MODE_TOOLS,
} from "./tools/constants.js";
import { getToolMode, type ToolMode } from "./schemas.js";

function getEnabledToolNames(mode: ToolMode): string[] {
  switch (mode) {
    case "full":
    case "lite":
      return [...IMPLEMENTED_TOOLS];
    case "minimal":
    default:
      return [...IMPLEMENTED_TOOLS].filter((name) =>
        (MINIMAL_MODE_TOOLS as readonly string[]).includes(name),
      );
  }
}

export function registerAllTools(server: McpServer, client: GodotClient): void {
  const mode = getToolMode();
  const enabled = new Set(getEnabledToolNames(mode));

  console.error(
    `[godot-mcp] Tool mode: ${mode}; registering ${enabled.size} working tool(s)`,
  );

  registerServerTools(server, client, enabled);
  registerProjectTools(server, client, enabled);
  registerSceneTools(server, client, enabled);
  registerNodeTools(server, client, enabled);
  registerScriptTools(server, client, enabled);
  registerEditorTools(server, client, enabled);
  registerResourceTools(server, client, enabled);
  registerBatchRefactorTools(server, client, enabled);
  registerRuntimeTools(server, client, enabled);
  registerInputTools(server, client, enabled);
  registerTestingQaTools(server, client, enabled);
  registerAnimationTools(server, client, enabled);
  registerAnimationTreeTools(server, client, enabled);
  registerTilemapTools(server, client, enabled);
}

export { IMPLEMENTED_TOOLS, PLANNED_TOOLS } from "./tools/constants.js";
