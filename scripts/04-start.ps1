param(
    [string]$Model = "",
    [string]$WorkDir = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "..\.local-config.json"

# Load local config
$apiKey = ""
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        $apiKey = $cfg.apiKey
        if (-not $Model -and $cfg.model) { $Model = $cfg.model }
    } catch {}
}

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host "[X] API Key not found. Run scripts/03-config.ps1 first." -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "deepseek-flash" }
if ([string]::IsNullOrWhiteSpace($WorkDir)) { $WorkDir = (Get-Location).Path }

Write-Host ""
Write-Host "===== Starting Claude Code =====" -ForegroundColor Cyan
Write-Host "Model:     $Model"
Write-Host "WorkDir:   $WorkDir"
Write-Host ""

$cliCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($null -eq $cliCmd) {
    Write-Host "[X] Claude Code not installed. Run scripts/02-install-cc.ps1 first." -ForegroundColor Red
    exit 1
}

$node = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $node) {
    Write-Host "[X] Node.js not installed" -ForegroundColor Red
    exit 1
}

function Get-FreeTcpPort {
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try { return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port }
    finally { $listener.Stop() }
}

$sessionId = [Guid]::NewGuid().ToString("N")
$tempDir = Join-Path $env:TEMP ("cc-env-setup-" + $sessionId)
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

if (PARENT_PID) {
  const watchdog = setInterval(() => {
    try { process.kill(PARENT_PID, 0); } catch { process.exit(0); }
  }, 1000);
  watchdog.unref();
}

function stripCacheControl(value) {
  if (!value || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(stripCacheControl).filter(Boolean);
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (k === "cache_control") continue;
    out[k] = stripCacheControl(v);
  }
  return out;
}

function textFromContent(c) {
  if (c === undefined || c === null) return "";
  if (typeof c === "string") return c;
  if (Array.isArray(c)) return c.map(b => {
    if (typeof b === "string") return b;
    if (b && typeof b === "object" && typeof b.text === "string") return b.text;
    return "";
  }).filter(Boolean).join("\n");
  return String(c);
}

function sanitizeContent(content) {
  if (content === undefined || content === null) return "";
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return String(content);
  const kept = [];
  for (const raw of content) {
    if (!raw || typeof raw !== "object") continue;
    const block = stripCacheControl(raw);
    if (block.type === "thinking" || block.type === "redacted_thinking") continue;
    if (block.type === "text" && block.text === "") continue;
    if (block.type === "tool_use") {
      kept.push({ type: "tool_use", id: block.id, name: block.name, input: block.input || {} });
      continue;
    }
    if (block.type === "tool_result") {
      const tr = { type: "tool_result", tool_use_id: block.tool_use_id, content: sanitizeContent(block.content) };
      if (block.is_error === true) tr.is_error = true;
      kept.push(tr); continue;
    }
    if (block.type === "text") { kept.push({ type: "text", text: String(block.text || "") }); continue; }
    if (block.type === "image") { kept.push(block); continue; }
  }
  if (kept.length === 0) return "";
  return kept;
}

function transformBody(input) {
  if (!input || typeof input !== "object") return input;
  const body = { ...input };
  for (const k of ["thinking","output_config","context_management","mcp_servers","container","service_tier"]) {
    delete body[k];
  }
  const allowed = new Set(["model","max_tokens","messages","system","stream","stop_sequences","temperature","top_p","top_k","tools","tool_choice","metadata"]);
  for (const k of Object.keys(body)) { if (!allowed.has(k)) delete body[k]; }
  const kept = []; const movedSystem = [];
  if (Array.isArray(body.messages)) {
    for (const m of body.messages) {
      if (!m || typeof m !== "object") continue;
      if (m.role === "system") { const t = textFromContent(m.content); if (t) movedSystem.push(t); continue; }
      if (m.role !== "user" && m.role !== "assistant") continue;
      kept.push({ role: m.role, content: sanitizeContent(m.content) });
    }
    body.messages = kept;
  }
  const sys = [textFromContent(body.system), ...movedSystem].filter(Boolean).join("\n");
  if (sys) body.system = sys; else delete body.system;
  return body;
}

function sanitizeHeaders(h) {
  const out = { ...h };
  delete out["anthropic-beta"]; delete out["host"]; delete out["connection"];
  delete out["keep-alive"]; delete out["transfer-encoding"]; delete out["upgrade"];
  out["host"] = UPSTREAM.host;
  return out;
}

const server = http.createServer((req, res) => {
  if (req.url === "/__health") { res.writeHead(200); res.end("ok"); return; }
  const chunks = [];
  req.on("data", c => chunks.push(c));
  req.on("end", () => {
    let body = Buffer.concat(chunks);
    const ct = String(req.headers["content-type"] || "").toLowerCase();
    if (body.length && ct.includes("application/json")) {
      try { body = Buffer.from(JSON.stringify(transformBody(JSON.parse(body.toString("utf8")))), "utf8"); } catch {}
    }
    const headers = sanitizeHeaders(req.headers);
    delete headers["content-length"]; headers["content-length"] = String(body.length);
    const transport = UPSTREAM.protocol === "https:" ? https : http;
    const options = {
      protocol: UPSTREAM.protocol, hostname: UPSTREAM.hostname,
      port: UPSTREAM.port || (UPSTREAM.protocol === "https:" ? 443 : 80),
      servername: UPSTREAM.protocol === "https:" ? UPSTREAM.hostname : undefined,
      method: req.method, path: req.url, headers
    };
    const upstream = transport.request(options, ur => {
      const hd = { ...ur.headers };
      delete hd["connection"]; delete hd["keep-alive"]; delete hd["transfer-encoding"];
      res.writeHead(ur.statusCode || 502, hd);
      ur.pipe(res);
    });
    upstream.on("error", e => { if (!res.headersSent) res.writeHead(502); res.end(JSON.stringify({ error: e.message })); });
    upstream.end(body);
  });
});
server.listen(PORT, "127.0.0.1");
'@

Set-Content -Path $proxyPath -Value $proxyCode -Encoding ASCII

$sessionSettings = @{
    env = @{
        ANTHROPIC_BASE_URL = "http://127.0.0.1:$Port"
        ANTHROPIC_AUTH_TOKEN = $apiKey
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
    $quotedProxy = '"' + $proxyPath + '"'
    $proxyProcess = Start-Process -FilePath $node.Source -ArgumentList @($quotedProxy, "$Port", "$PID", "https://tokenrhythm.studio") -WindowStyle Hidden -PassThru

    $ready = $false
    for ($i = 0; $i -lt 40; $i++) {
        try {
            Invoke-RestMethod -Uri "http://127.0.0.1:$Port/__health" -Method Get -TimeoutSec 1 | Out-Null
            $ready = $true; break
        } catch { Start-Sleep -Milliseconds 200 }
    }
    if (-not $ready) { throw "Proxy failed to start" }

    Write-Host "[OK] Local proxy: http://127.0.0.1:$Port" -ForegroundColor Green
    Write-Host "[OK] Upstream:    https://tokenrhythm.studio" -ForegroundColor Green
    Write-Host "[OK] Model:       $Model" -ForegroundColor Green
    Write-Host ""
    Write-Host "Starting Claude Code (cleans up on exit)..." -ForegroundColor Yellow
    Write-Host ""

    Push-Location $WorkDir
    try {
        & $cliCmd.Source --settings $settingsPath --model $Model
    } finally {
        Pop-Location
    }
}
finally {
    if ($null -ne $proxyProcess -and -not $proxyProcess.HasExited) {
        Stop-Process -Id $proxyProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host ""
    Write-Host "[OK] Temporary proxy and files cleaned up" -ForegroundColor Green
}