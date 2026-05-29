/**
 * In-memory session log for get_recent_changes and flag_chat_health.
 * Resets when the MCP server process restarts.
 */

export interface SessionCallRecord {
  timestamp: string;
  tool: string;
  params_summary: string;
  ok: boolean;
  error_message?: string;
}

const MAX_RECORDS = 300;
const records: SessionCallRecord[] = [];

const REPEAT_WINDOW = 8;
const REPEAT_THRESHOLD = 4;

function stableParamsSummary(params: Record<string, unknown>): string {
  const keys = Object.keys(params).sort();
  const parts: string[] = [];
  for (const k of keys) {
    const v = params[k];
    if (v === undefined) continue;
    if (typeof v === "string") {
      parts.push(`${k}=${v.length > 60 ? v.slice(0, 60) + "…" : v}`);
    } else if (typeof v === "number" || typeof v === "boolean") {
      parts.push(`${k}=${v}`);
    } else {
      parts.push(`${k}=…`);
    }
  }
  return parts.join(", ") || "(no params)";
}

function fingerprint(tool: string, params: Record<string, unknown>): string {
  return `${tool}|${stableParamsSummary(params)}`;
}

export function recordToolCall(
  tool: string,
  params: Record<string, unknown>,
  ok: boolean,
  errorMessage?: string,
): void {
  records.push({
    timestamp: new Date().toISOString(),
    tool,
    params_summary: stableParamsSummary(params),
    ok,
    error_message: errorMessage,
  });
  while (records.length > MAX_RECORDS) {
    records.shift();
  }
}

export function clearSessionTracker(): void {
  records.length = 0;
}

export function getRecentChanges(maxEntries = 30): SessionCallRecord[] {
  return records.slice(-maxEntries);
}

export interface ChatHealthReport {
  healthy: boolean;
  warnings: string[];
  plain_english: string;
  repeated_tool_pattern?: string;
  repeated_error_pattern?: string;
  recent_failure_count: number;
}

export function checkChatHealth(): ChatHealthReport {
  const warnings: string[] = [];
  const recent = records.slice(-REPEAT_WINDOW);

  if (recent.length >= REPEAT_THRESHOLD) {
    const counts = new Map<string, number>();
    for (const r of recent) {
      const fp = `${r.tool}|${r.params_summary}`;
      counts.set(fp, (counts.get(fp) ?? 0) + 1);
    }
    for (const [fp, count] of counts) {
      if (count >= REPEAT_THRESHOLD) {
        const [tool] = fp.split("|");
        warnings.push(
          `Tool "${tool}" was called ${count} times in the last ${REPEAT_WINDOW} MCP calls with the same parameters — likely a loop.`,
        );
        return buildReport(warnings, fp, undefined);
      }
    }
  }

  const recentErrors = recent.filter((r) => !r.ok && r.error_message);
  if (recentErrors.length >= 3) {
    const errCounts = new Map<string, number>();
    for (const r of recentErrors) {
      const sig = r.error_message!.slice(0, 120);
      errCounts.set(sig, (errCounts.get(sig) ?? 0) + 1);
    }
    for (const [sig, count] of errCounts) {
      if (count >= 3) {
        warnings.push(
          `The same error appeared ${count} times recently: ${sig.slice(0, 80)}…`,
        );
        return buildReport(warnings, undefined, sig);
      }
    }
  }

  const failureCount = records.filter((r) => !r.ok).length;
  if (records.length > 25 && failureCount / records.length > 0.5) {
    warnings.push(
      `Over half of MCP calls in this session failed (${failureCount}/${records.length}). Consider restarting the Cursor chat and calling initialize_session again.`,
    );
  }

  return buildReport(warnings, undefined, undefined);
}

function buildReport(
  warnings: string[],
  repeatedTool?: string,
  repeatedError?: string,
): ChatHealthReport {
  const recentFailures = records.filter((r) => !r.ok).length;
  if (warnings.length === 0) {
    return {
      healthy: true,
      warnings: [],
      plain_english: `Session looks healthy (${records.length} tool call(s) logged, ${recentFailures} failure(s)).`,
      recent_failure_count: recentFailures,
    };
  }

  return {
    healthy: false,
    warnings,
    plain_english:
      warnings.join(" ") +
      " Start a fresh Cursor chat, call list_available_tools → get_capabilities → initialize_session, then retry once. Do not tell the model to 'stop repeating' — that often makes loops worse.",
    repeated_tool_pattern: repeatedTool,
    repeated_error_pattern: repeatedError,
    recent_failure_count: recentFailures,
  };
}
