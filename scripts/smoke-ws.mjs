import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);
const method = process.argv[2] ?? "godot_ping";
const params = process.argv[3] ? JSON.parse(process.argv[3]) : {};

const ws = new WebSocket(`ws://127.0.0.1:${port}`);
ws.on("open", () => {
  ws.send(JSON.stringify({ id: "cli-test", method, params }));
});
ws.on("message", (data) => {
  console.log(data.toString());
  ws.close();
  process.exit(0);
});
ws.on("error", (err) => {
  console.error("Error:", err.message);
  console.error("Run from repo root after: npm install");
  console.error("Ensure Godot is open with the MCP plugin enabled.");
  process.exit(1);
});
setTimeout(() => {
  console.error("Timeout waiting for Godot");
  process.exit(1);
}, 10_000);
