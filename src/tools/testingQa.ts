import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const testingQaToolSchemas = {
  get_editor_screenshot: z
    .object({
      viewport: z.enum(["2d", "3d"]).optional().default("2d"),
      viewport_3d_index: z.number().int().min(0).max(3).optional().default(0),
      save: z.boolean().optional().default(false),
    })
    .strict(),
  get_game_screenshot: z
    .object({
      save: z.boolean().optional().default(false),
    })
    .strict(),
  capture_frames: z
    .object({
      count: z.number().int().min(1).max(30).optional().default(3),
      delay_ms: z.number().int().min(50).max(5000).optional().default(200),
      target: z
        .enum(["editor_2d", "editor_3d", "game"])
        .optional()
        .default("editor_2d"),
      save: z.boolean().optional().default(false),
    })
    .strict(),
  compare_screenshots: z
    .object({
      image_a: z.string().describe("res:// or user:// path to PNG"),
      image_b: z.string().describe("res:// or user:// path to PNG"),
      max_diff_ratio: z
        .number()
        .min(0)
        .max(1)
        .optional()
        .default(0)
        .describe("Max allowed differing pixel ratio (0 = exact match)"),
    })
    .strict(),
  start_recording: z
    .object({
      target: z
        .enum(["editor_2d", "editor_3d", "game"])
        .optional()
        .default("editor_2d"),
      interval_ms: z.number().int().min(50).max(5000).optional().default(200),
    })
    .strict(),
  stop_recording: z.object({}).strict(),
  replay_recording: z.object({}).strict(),
  run_test_scenario: z
    .object({
      name: z.string().optional(),
      steps: z.array(
        z.object({
          tool: z.string().optional(),
          method: z.string().optional(),
          params: z.record(z.unknown()).optional().default({}),
        }),
      ),
    })
    .strict(),
  assert_node_state: z
    .object({
      node_path: z.string(),
      property: z.string(),
      expected: z.unknown(),
      runtime: z.boolean().optional().default(false),
    })
    .strict(),
  assert_screen_text: z
    .object({
      text: z.string(),
      runtime: z.boolean().optional().default(false),
    })
    .strict(),
  run_stress_test: z
    .object({
      tool: z.string().optional().default("godot_ping"),
      iterations: z.number().int().min(1).max(500).optional().default(50),
      params: z.record(z.unknown()).optional().default({}),
    })
    .strict(),
  get_test_report: z.object({}).strict(),
  monitor_properties: z
    .object({
      monitor_id: z.string().optional().default("default"),
      action: z.enum(["snapshot", "diff", "clear"]).optional().default("snapshot"),
      node_path: z.string().optional(),
      properties: z.array(z.string()).optional(),
      runtime: z.boolean().optional().default(false),
    })
    .strict(),
};

export function registerTestingQaTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  const tools: Array<{
    name: keyof typeof testingQaToolSchemas;
    description: string;
  }> = [
    {
      name: "get_editor_screenshot",
      description: "Capture the 2D or 3D editor viewport as PNG base64.",
    },
    {
      name: "get_game_screenshot",
      description: "Capture the running game viewport as PNG base64.",
    },
    {
      name: "capture_frames",
      description: "Capture multiple frames with delay between captures.",
    },
    {
      name: "compare_screenshots",
      description: "Compare two PNG images and report pixel differences.",
    },
    {
      name: "start_recording",
      description: "Start interval-based frame recording.",
    },
    {
      name: "stop_recording",
      description: "Stop recording and return captured frames.",
    },
    {
      name: "replay_recording",
      description: "Return metadata from the last recording session.",
    },
    {
      name: "run_test_scenario",
      description: "Run a sequence of MCP tool calls and report results.",
    },
    {
      name: "assert_node_state",
      description: "Assert a node property equals an expected value.",
    },
    {
      name: "assert_screen_text",
      description: "Find Label/Button text in the edited or runtime scene.",
    },
    {
      name: "run_stress_test",
      description: "Repeatedly invoke a tool and report timing stats.",
    },
    {
      name: "get_test_report",
      description: "Return the last test scenario or stress test report.",
    },
    {
      name: "monitor_properties",
      description: "Snapshot or diff node properties over time.",
    },
  ];

  for (const { name, description } of tools) {
    registerGodotTool(
      server,
      client,
      enabled,
      name,
      description,
      testingQaToolSchemas[name].shape,
    );
  }
}
