import { z } from "zod";
import type { GodotClient } from "../godot-client.js";
import { callGodot, registerTool } from "./helpers.js";
import { setToolCategory } from "./spec.js";
import {
  checkChatHealth,
  clearSessionTracker,
  getRecentChanges,
} from "./session-tracker.js";

export function registerGuardrailTools(client: GodotClient): void {
  registerTool(client, {
    name: "flag_chat_health",
    description:
      "Detects repetition loops and repeated errors in this MCP server session. Call when tools keep failing or repeating with the same parameters.",
    schema: z.object({}),
    handler: async () => checkChatHealth(),
  });
  setToolCategory("flag_chat_health", "project");

  registerTool(client, {
    name: "get_recent_changes",
    description:
      "Lists recent MCP tool calls in this server session (tool name, params summary, success/failure). Use to self-review before declaring a task done.",
    schema: z.object({
      max_entries: z.number().optional().default(30),
      errors_only: z.boolean().optional().default(false),
    }),
    handler: async (_c, args) => {
      let entries = getRecentChanges(args.max_entries);
      if (args.errors_only) {
        entries = entries.filter((e) => !e.ok);
      }
      return {
        entries,
        count: entries.length,
        plain_english:
          entries.length === 0
            ? "No MCP tool calls recorded yet in this server session."
            : `Last ${entries.length} MCP call(s): ${entries.map((e) => `${e.ok ? "OK" : "ERR"} ${e.tool}`).join(", ")}.`,
      };
    },
  });
  setToolCategory("get_recent_changes", "project");

  registerTool(client, {
    name: "get_class_doc",
    description:
      "Godot 4 ClassDB reference for a built-in class: parent class, methods, properties, signals, and brief doc. Use before inventing API names. Optional search filters class list when class_name is partial.",
    schema: z.object({
      class_name: z.string().describe("e.g. CharacterBody3D, AnimationPlayer"),
      include_inherited: z
        .boolean()
        .optional()
        .default(true)
        .describe("Include inherited methods/properties"),
      max_methods: z.number().optional().default(40),
      max_properties: z.number().optional().default(30),
    }),
    handler: async (c, args) => callGodot(c, "get_class_doc", args as Record<string, unknown>),
  });
  setToolCategory("get_class_doc", "editor");

  registerTool(client, {
    name: "get_project_memory",
    description:
      "Read persistent project notes (stored in user://mcp_project_memory.json in Godot).",
    schema: z.object({}),
    handler: async (c) => callGodot(c, "get_project_memory", {}),
  });
  setToolCategory("get_project_memory", "project");

  registerTool(client, {
    name: "set_project_memory",
    description:
      "Append a project fact that survives chat compaction (architecture, naming, main scene path, etc.). Call after important decisions.",
    schema: z.object({
      fact: z.string().min(1).describe("One sentence fact to remember"),
    }),
    handler: async (c, args) =>
      callGodot(c, "set_project_memory", { fact: args.fact }),
  });
  setToolCategory("set_project_memory", "project");

  registerTool(client, {
    name: "remove_project_memory",
    description: "Remove a fact from project memory by exact text match.",
    schema: z.object({
      fact: z.string().describe("Exact fact string to remove"),
    }),
    handler: async (c, args) =>
      callGodot(c, "remove_project_memory", { fact: args.fact }),
  });
  setToolCategory("remove_project_memory", "project");

  registerTool(client, {
    name: "clear_project_memory",
    description: "Clear all saved project memory facts.",
    schema: z.object({}),
    handler: async (c) => callGodot(c, "clear_project_memory", {}),
  });
  setToolCategory("clear_project_memory", "project");

  registerTool(client, {
    name: "clear_session_tracker",
    description:
      "Clear the in-memory MCP session call log (get_recent_changes / flag_chat_health). Does not clear Godot project memory.",
    schema: z.object({}),
    handler: async () => {
      clearSessionTracker();
      return {
        cleared: true,
        plain_english: "In-memory session tool log cleared.",
      };
    },
  });
  setToolCategory("clear_session_tracker", "project");
}
