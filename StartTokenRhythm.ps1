param(
    [string]$Model = "deepseek-flash",
    [string]$ApiKey = "sk_tr_YOUR_KEY_HERE",
    [ValidateSet("high", "max")]
    [string]$Effort = "high",
    [ValidateSet("auto", "claude", "clawgod")]
    [string]$Cli = "auto"
)

$ErrorActionPreference = "Stop"

function Get-FreeTcpPort {
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Convert-SecureToPlainText {
    param([System.Security.SecureString]$SecureString)

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

Write-Host ""
Write-Host "Claude Code / ClawGod + TokenRhythm temporary session v4"
Write-Host "Compatibility fixes: beta headers + request schema sanitizer + debug logging."
Write-Host "No persistent environment changes will be made."
Write-Host ""

# --- CLI selection: claude or clawgod ---
$candidates = [ordered]@{}
foreach ($name in @("claude", "clawgod")) {
    $found = Get-Command $name -ErrorAction SilentlyContinue
    if ($null -ne $found) { $candidates[$name] = $found }
}

if ($Cli -ne "auto") {
    if (-not $candidates.Contains($Cli)) {
        throw "$Cli was not found in PATH."
    }
    $cliName = $Cli
}
elseif ($candidates.Count -eq 0) {
    throw "Neither claude nor clawgod was found in PATH."
}
elseif ($candidates.Count -eq 1) {
    $cliName = @($candidates.Keys)[0]
}
else {
    Write-Host "Both CLIs found in PATH:"
    Write-Host "  [1] claude   ($($candidates['claude'].Source))"
    Write-Host "  [2] clawgod  ($($candidates['clawgod'].Source))"
    $choice = Read-Host "Choose CLI [1/2, default 1]"
    $cliName = if ($choice -eq "2") { "clawgod" } else { "claude" }
}

$cliCmd = $candidates[$cliName]

$node = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $node) {
    throw "node was not found in PATH. Install Node.js 18 or newer."
}

Write-Host "[OK] ${cliName}: $($cliCmd.Source)"
Write-Host "[OK] node:    $($node.Source)"

$providerPath = Join-Path $HOME (".$cliName\provider.json")
if (Test-Path $providerPath) {
    try {
        $provider = Get-Content $providerPath -Raw | ConvertFrom-Json
        if ($null -ne $provider.apiKey -and -not [string]::IsNullOrWhiteSpace([string]$provider.apiKey)) {
            throw "$cliName provider.json has a non-empty apiKey and may override this temporary session. Clear apiKey in $providerPath, then run this launcher again."
        }
    }
    catch {
        if ($_.Exception.Message -like "*provider.json has a non-empty apiKey*") {
            throw
        }
        Write-Host "[WARN] Could not parse $providerPath. Continuing."
    }
}

$ApiKey = $ApiKey.Trim()
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "API key cannot be empty."
}

$sessionId = [Guid]::NewGuid().ToString("N")
$tempDir = Join-Path $env:TEMP ("$cliName-tokenrhythm-" + $sessionId)
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$proxyPath = Join-Path $tempDir "proxy.js"
$settingsPath = Join-Path $tempDir "settings.json"
$Port = Get-FreeTcpPort

$proxyCode = @'
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
'@

Set-Content -Path $proxyPath -Value $proxyCode -Encoding ASCII

$sessionSettings = @{
    env = @{
        ANTHROPIC_BASE_URL = "http://127.0.0.1:$Port"
        ANTHROPIC_AUTH_TOKEN = $ApiKey
        ANTHROPIC_API_KEY = ""
        ANTHROPIC_MODEL = $Model
        ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
        ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
        ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
        ANTHROPIC_DEFAULT_FABLE_MODEL = $Model
        CLAUDE_CODE_SUBAGENT_MODEL = $Model
        CLAUDE_CODE_EFFORT_LEVEL = ""
        CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1"
        DISABLE_INTERLEAVED_THINKING = "1"
        ENABLE_TOOL_SEARCH = "false"
        ANTHROPIC_BETAS = ""
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
    }
}

$sessionSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding ASCII

$proxyProcess = $null

try {
    $quotedProxyPath = '"' + $proxyPath + '"'
    $proxyProcess = Start-Process -FilePath $node.Source -ArgumentList @($quotedProxyPath, "$Port", "$PID", "https://tokenrhythm.studio") -WindowStyle Hidden -PassThru

    $ready = $false
    for ($i = 0; $i -lt 40; $i++) {
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/__health" -Method Get -TimeoutSec 1
            if ($health.ok -eq $true) {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 200
        }
    }

    if (-not $ready) {
        throw "Temporary proxy failed to start."
    }

    Write-Host ""
    Write-Host "[OK] Temporary proxy: http://127.0.0.1:$Port"
    Write-Host "[OK] Upstream:        https://tokenrhythm.studio"
    Write-Host "[OK] Model:           $Model"
    Write-Host "[OK] Effort:          sanitized for TokenRhythm"
    Write-Host ""
    Write-Host "Starting $cliName. Exit $cliName to remove all temporary files."
    Write-Host ""

    & $cliCmd.Source --settings $settingsPath --model $Model --effort $Effort
}
finally {
    Write-Host ""
    Write-Host "Cleaning temporary session..."

    if ($null -ne $proxyProcess) {
        try {
            if (-not $proxyProcess.HasExited) {
                Stop-Process -Id $proxyProcess.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
        }
    }

    try {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
    }

    $ApiKey = $null

    Write-Host "[OK] Temporary proxy stopped."
    Write-Host "[OK] Temporary settings deleted."
    Write-Host "[OK] No user or system environment variables were changed."
    Write-Host "[OK] User $cliName settings were not modified."
}
