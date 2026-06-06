#!/usr/bin/env python3
"""Minimal MCP stdio server to probe Cursor headless elicitation support (M009 Q1).

Logs everything to $MCP_LOG. Two signals of interest:
  1. The client's declared `capabilities` in the `initialize` request — if it
     advertises `elicitation`, headless cursor-agent supports interactive
     mid-run prompts. (Cheap, near-definitive.)
  2. What happens when a tool call triggers a server->client
     `elicitation/create` request: rendered / auto-declined / error / timeout.

stdio transport = newline-delimited JSON-RPC (no Content-Length framing).
"""
import sys, os, json, select, time

LOG = os.environ.get("MCP_LOG", "/tmp/mcp-elicit-probe/server.log")

def log(msg):
    with open(LOG, "a") as f:
        f.write(msg + "\n")
        f.flush()

def send(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()
    log("SEND " + json.dumps(obj))

def read_line(timeout=None):
    if timeout is not None:
        r, _, _ = select.select([sys.stdin], [], [], timeout)
        if not r:
            return None
    line = sys.stdin.readline()
    if line == "":
        return ""  # EOF
    return line

def main():
    log("=== server start pid=%d ts=%s ===" % (os.getpid(), time.strftime("%H:%M:%S")))
    client_caps_logged = False
    while True:
        line = read_line()
        if line == "":
            log("EOF on stdin — exiting")
            break
        line = line.strip()
        if not line:
            continue
        log("RECV " + line)
        try:
            msg = json.loads(line)
        except Exception as e:
            log("PARSE-ERR %s" % e)
            continue

        method = msg.get("method")
        mid = msg.get("id")

        if method == "initialize":
            caps = msg.get("params", {}).get("capabilities", {})
            client_info = msg.get("params", {}).get("clientInfo", {})
            proto = msg.get("params", {}).get("protocolVersion", "2025-06-18")
            log("CLIENT_INFO " + json.dumps(client_info))
            log("CLIENT_CAPABILITIES " + json.dumps(caps))
            log("CLIENT_SUPPORTS_ELICITATION=%s" % ("elicitation" in caps))
            client_caps_logged = True
            send({"jsonrpc": "2.0", "id": mid, "result": {
                "protocolVersion": proto,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "elicit-probe", "version": "0.0.1"},
            }})
        elif method == "notifications/initialized":
            log("INITIALIZED notification received")
        elif method == "tools/list":
            send({"jsonrpc": "2.0", "id": mid, "result": {"tools": [{
                "name": "ask_user",
                "description": "Ask the user a question via MCP elicitation and return their answer.",
                "inputSchema": {"type": "object", "properties": {
                    "question": {"type": "string"}}, "required": ["question"]},
            }]}})
        elif method == "tools/call":
            params = msg.get("params", {})
            tname = params.get("name")
            log("TOOL_CALL name=%s args=%s" % (tname, json.dumps(params.get("arguments", {}))))
            if tname == "ask_user":
                # Attempt a server->client elicitation/create request.
                elicit_id = "elicit-1"
                send({"jsonrpc": "2.0", "id": elicit_id, "method": "elicitation/create",
                      "params": {
                          "message": "What is your favorite color?",
                          "requestedSchema": {"type": "object", "properties": {
                              "color": {"type": "string", "title": "Favorite color"}},
                              "required": ["color"]},
                      }})
                log("ELICIT_SENT id=%s — waiting up to 25s for client response" % elicit_id)
                # Wait for the elicitation response (or anything) on stdin.
                deadline = time.time() + 25
                resolved = None
                while time.time() < deadline:
                    l = read_line(timeout=max(0.1, deadline - time.time()))
                    if l is None:
                        continue  # timeout tick
                    if l == "":
                        log("ELICIT_EOF — client closed during elicitation")
                        resolved = {"eof": True}
                        break
                    l = l.strip()
                    if not l:
                        continue
                    log("RECV(during-elicit) " + l)
                    try:
                        em = json.loads(l)
                    except Exception as e:
                        log("ELICIT_PARSE_ERR %s" % e)
                        continue
                    if em.get("id") == elicit_id:
                        log("ELICIT_RESPONSE " + json.dumps(em))
                        resolved = em
                        break
                    else:
                        log("ELICIT_OTHER_MSG (id=%s) — ignoring" % em.get("id"))
                if resolved is None:
                    log("ELICIT_TIMEOUT — no response in 25s")
                    answer = "TIMEOUT: no elicitation response"
                elif resolved.get("eof"):
                    answer = "EOF during elicitation"
                elif "error" in resolved:
                    answer = "elicitation error: " + json.dumps(resolved["error"])
                else:
                    answer = "elicitation result: " + json.dumps(resolved.get("result"))
                send({"jsonrpc": "2.0", "id": mid, "result": {
                    "content": [{"type": "text", "text": answer}]}})
            else:
                send({"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": "unknown tool"}})
        elif mid is not None:
            # Unknown request — respond with method-not-found.
            send({"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": "method not found: %s" % method}})
        else:
            log("NOTIFY (no id) method=%s — ignoring" % method)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log("FATAL %r" % e)
        raise
