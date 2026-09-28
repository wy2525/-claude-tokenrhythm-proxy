"use strict";

const http = require("node:http");
const https = require("node:https");
const { URL } = require("node:url");

const PORT = Number(process.argv[2]);
const PARENT_PID = Number(process.argv[3]);
const UPSTREAM = new URL(process.argv[4] || "https://tokenrhythm.studio");
const LISTEN_HOST = "127.0.0.1";

if (PARENT_PID) {
  const watchdog = setInterval(() => {
    try {
      process.kill(PARENT_PID, 0);
    } catch {
      process.exit(0);
    }
  }, 1000);
  watchdog.unref();
}

function cleanPath(rawUrl) {
  const url = new URL(rawUrl || "/", "http://localhost");
  url.searchParams.delete("beta");
  return url.pathname + url.search;
}

function textFromContent(content) {
  if (content === undefined || content === null) return "";
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content.map((block) => {
      if (typeof block === "string") return block;
      if (!block || typeof block !== "object") return "";
      if (typeof block.text === "string") return block.text;
      if (typeof block.content === "string") return block.content;
      return "";
    }).filter(Boolean).join("\n");
  }
  return String(content);
}

function stripCacheControl(value) {
  if (!value || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(stripCacheControl).filter((item) => item !== null);

  const out = {};
  for (const [key, child] of Object.entries(value)) {
    if (key === "cache_control") continue;
    out[key] = stripCacheControl(child);
  }
  return out;
}

function sanitizeContent(content, role) {
  if (content === undefined || content === null) return "";
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return String(content);

  const kept = [];
  for (const rawBlock of content) {
    if (!rawBlock || typeof rawBlock !== "object") continue;
    const block = stripCacheControl(rawBlock);

    if (block.type === "thinking" || block.type === "redacted_thinking") continue;
    if (block.type === "text" && typeof block.text === "string" && block.text.length === 0) continue;

    // TokenRhythm/DeepSeek-compatible Anthropic endpoints commonly reject
    // newer Claude Code block fields. Keep the core block contract only.
    if (block.type === "tool_use") {
      kept.push({ type: "tool_use", id: block.id, name: block.name, input: block.input || {} });
      continue;
    }
    if (block.type === "tool_result") {
      const tr = { type: "tool_result", tool_use_id: block.tool_use_id, content: sanitizeContent(block.content, "user") };
      if (block.is_error === true) tr.is_error = true;
      kept.push(tr);
      continue;
    }
    if (block.type === "text") {
      kept.push({ type: "text", text: String(block.text || "") });
      continue;
    }
    if (block.type === "image") {
      kept.push(block);
      continue;
    }
  }

  if (kept.length === 0) return "";
  return kept;
}

function sanitizeTool(tool) {
  if (!tool || typeof tool !== "object") return tool;
  const out = {
    name: tool.name,
    description: tool.description || "",
    input_schema: stripCacheControl(tool.input_schema || { type: "object", properties: {} })
  };
  return out;
}

function transformAnthropicBody(input) {
  if (!input || typeof input !== "object") {
    return { body: input, migrated: 0, stripped: [] };
  }

  const stripped = [];
  const body = { ...input };

  for (const key of [
    "thinking",
    "output_config",
    "context_management",
    "mcp_servers",
    "container",
    "service_tier"
  ]) {
    if (key in body) {
      delete body[key];
      stripped.push(key);
    }
  }

  const allowedTopLevel = new Set([
    "model",
    "max_tokens",
    "messages",
    "system",
    "stream",
    "stop_sequences",
    "temperature",
    "top_p",
    "top_k",
    "tools",
    "tool_choice",
    "metadata"
  ]);

  for (const key of Object.keys(body)) {
    if (!allowedTopLevel.has(key)) {
      delete body[key];
      stripped.push(key);
    }
  }

  const kept = [];
  const movedSystem = [];

  if (Array.isArray(body.messages)) {
    for (const message of body.messages) {
      if (!message || typeof message !== "object") continue;
      if (message.role === "system") {
        const text = textFromContent(message.content);
        if (text) movedSystem.push(text);
        continue;
      }
      if (message.role !== "user" && message.role !== "assistant") {
        stripped.push(`message_role:${message.role}`);
        continue;
      }
      kept.push({
        role: message.role,
        content: sanitizeContent(message.content, message.role)
      });
    }
    body.messages = kept;
  }

  const existingSystem = textFromContent(body.system);
  const systemText = [existingSystem, ...movedSystem].filter(Boolean).join("\n");
  if (systemText) body.system = systemText;
  else delete body.system;

  if (Array.isArray(body.tools)) body.tools = body.tools.map(sanitizeTool);
  if (body.metadata && typeof body.metadata === "object") body.metadata = stripCacheControl(body.metadata);

  return { body, migrated: movedSystem.length, stripped };
}

function sanitizeRequestHeaders(source) {
  const headers = { ...source };

  delete headers["anthropic-beta"];
  delete headers["host"];
  delete headers["connection"];
  delete headers["proxy-connection"];
  delete headers["keep-alive"];
  delete headers["transfer-encoding"];
  delete headers["upgrade"];

  if (headers["x-api-key"] !== undefined && String(headers["x-api-key"]).trim() === "") {
    delete headers["x-api-key"];
  }
  if (headers["authorization"] !== undefined && String(headers["authorization"]).trim().toLowerCase() === "bearer") {
    delete headers["authorization"];
  }

  headers["host"] = UPSTREAM.host;

  return headers;
}

function sanitizeResponseHeaders(source) {
  const headers = { ...source };

  delete headers["connection"];
  delete headers["keep-alive"];
  delete headers["transfer-encoding"];
  delete headers["upgrade"];

  return headers;
}

const server = http.createServer((req, res) => {
  if (req.url === "/__health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  const chunks = [];

  req.on("data", (chunk) => chunks.push(chunk));

  req.on("end", () => {
    let bodyBuffer = Buffer.concat(chunks);
    let migrated = 0;

    const contentType = String(req.headers["content-type"] || "").toLowerCase();
    const contentEncoding = String(req.headers["content-encoding"] || "").toLowerCase();

    if (
      bodyBuffer.length > 0 &&
      contentType.includes("application/json") &&
      (contentEncoding === "" || contentEncoding === "identity")
    ) {
      try {
        const parsed = JSON.parse(bodyBuffer.toString("utf8"));
        const result = transformAnthropicBody(parsed);
        migrated = result.migrated;

        if (migrated > 0 || result.stripped.length > 0) {
          bodyBuffer = Buffer.from(JSON.stringify(result.body), "utf8");
        }
        if (result.stripped.length > 0) {
          console.log(`[compat] stripped unsupported field(s): ${Array.from(new Set(result.stripped)).join(", ")}`);
        }
      } catch {
        // If parsing fails, forward the original body unchanged.
      }
    }

    const headers = sanitizeRequestHeaders(req.headers);

    delete headers["content-length"];
    headers["content-length"] = String(bodyBuffer.length);

    const transport = UPSTREAM.protocol === "https:" ? https : http;

    const options = {
      protocol: UPSTREAM.protocol,
      hostname: UPSTREAM.hostname,
      port: UPSTREAM.port || (UPSTREAM.protocol === "https:" ? 443 : 80),
      servername: UPSTREAM.protocol === "https:" ? UPSTREAM.hostname : undefined,
      method: req.method,
      path: cleanPath(req.url),
      headers
    };

    const upstream = transport.request(options, (upstreamResponse) => {
      const responseHeaders = sanitizeResponseHeaders(upstreamResponse.headers);
      const statusCode = upstreamResponse.statusCode || 502;

      if (statusCode >= 400) {
        const errorChunks = [];
        upstreamResponse.on("data", (chunk) => errorChunks.push(chunk));
        upstreamResponse.on("end", () => {
          const errorBody = Buffer.concat(errorChunks);
          console.error(`[upstream-error] HTTP ${statusCode}: ${errorBody.toString("utf8").slice(0, 2000)}`);
          res.writeHead(statusCode, responseHeaders);
          res.end(errorBody);
        });
        return;
      }

      res.writeHead(statusCode, responseHeaders);
      upstreamResponse.pipe(res);
    });

    upstream.setTimeout(600000, () => {
      upstream.destroy(new Error("TokenRhythm timeout"));
    });

    upstream.on("error", (error) => {
      if (!res.headersSent) {
        res.writeHead(502, { "content-type": "application/json" });
      }

      if (!res.writableEnded) {
        res.end(JSON.stringify({
          type: "error",
          error: {
            type: "tokenrhythm_proxy_error",
            message: error.message
          }
        }));
      }
    });

    if (migrated > 0) {
      console.log(`[compat] moved ${migrated} system block(s) from messages[] to top-level system`);
    }

    upstream.end(bodyBuffer);
  });
});

server.listen(PORT, LISTEN_HOST);
