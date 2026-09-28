# Claude Code + TokenRhythm (基元律动) 本地兼容代理

> **中文简介：** 本项目解决 Claude Code 与基元律动（TokenRhythm，https://tokenrhythm.studio）网关之间的协议不兼容问题。通过在本地架设一个清洗代理，把 Claude Code 新版请求中网关不认识的字段（如 `anthropic-beta` 请求头、`thinking`、`cache_control` 等）过滤掉，让 Claude Code 能正常调用 TokenRhythm 的 DeepSeek / GLM 等模型。支持图形界面一键启动、API Key 切换、模型选择，退出后自动清理临时文件与代理进程，不污染系统环境变量。

## 问题背景

Claude Code (新版) 发送请求时带以下 TokenRhythm 网关不认识的字段，导致 HTTP 400：

| 违禁品 | 位置 | 后果 |
| --- | --- | --- |
| `anthropic-beta` | 请求头 | 400 |
| `thinking` / `output_config` / `context_management` / `service_tier` | 顶层字段 | 400 |
| `thinking` / `redacted_thinking` block | messages[] | 400 |
| `cache_control` | 每个 block | 400 |
| `role: "system"` 混在消息列表里 | messages[] | 400 |
| tool_use / tool_result 的扩展字段 | messages[] / tools[] | 400 |

## 解决方案

在 `127.0.0.1` 架一个本地代理，把 Claude Code 的请求「清洗」成 TokenRhythm 认识的格式再转发。

```
Claude Code ──→ http://127.0.0.1:<端口> ──→ https://tokenrhythm.studio
                    │
                    └─ 清洗：去 beta 头、system 归位、删 thinking/cache_control 等
```

## 环境要求

- Node.js 18+
- Claude Code **2.1.153**（旧版，不校验自定义模型名、不强制登录）

> 新版 Claude Code (2.1.283+) 会校验模型目录并强制登录，无法使用。请降级：
> ```
> npm install -g @anthropic-ai/claude-code@2.1.153
> ```

## 使用方法

### 方式一：命令行

在**目标项目目录**下运行（Claude Code 会在此目录打开）：

```powershell
powershell -ExecutionPolicy Bypass -File StartTokenRhythm.ps1
```

指定 Key、模型、工作目录：

```powershell
powershell -ExecutionPolicy Bypass -File StartTokenRhythm.ps1 -ApiKey "sk_tr_YOUR_KEY" -Model "deepseek-flash" -WorkDir "E:\你的项目目录"
```

**参数说明：**
| 参数 | 说明 | 默认值 |
| --- | --- | --- |
| `-ApiKey` | TokenRhythm API Key | 无 |
| `-Model` | 使用的模型 | `deepseek-flash` |
| `-WorkDir` | Claude Code 工作目录（打开的目录） | 调用脚本时所在目录 |
| `-Effort` | 推理强度（high/max） | `high` |
| `-Cli` | 使用的 CLI（auto/claude/clawgod） | `auto` |

### 方式二：图形界面 (UI) — 推荐

双击 `LaunchUI.bat` 打开图形界面，支持：

1. **API Key** — 自动读取本地 `.local-config.json`（若存在），也可手动编辑
2. **模型选择** — 下拉选择支持 Anthropic 协议的模型
3. **工作目录选择** — 点击 **Browse...** 选择 Claude Code 打开的文件夹
4. **一键启动** — 自动启动本地清洗代理 + Claude Code，退出后自动清理

#### 本地配置 Key（可选，推荐）

为避免在公共脚本中硬编码真实 Key，可在脚本同目录创建 `.local-config.json`（该文件已被 `.gitignore` 排除，不会推送）：

```json
{
  "apiKey": "sk_tr_你的真实Key"
}
```

UI 启动时会自动读取该文件填入 Key，无需每次手动输入。

## 支持的模型

仅支持 `supports_anthropic: true` 的模型（可通过网关 `/v1/models` 查询）：

- `deepseek-flash`
- `glm-5.3-flashx`
- `deepseek-v4-pro-0813`
- `mimo-v2.6-pro`

> 在 `StartTokenRhythm.ps1` 顶部修改默认模型，或通过 `-Model` 参数指定。

## 说明

- 脚本启动本地代理 + Claude Code，退出 Claude Code 后自动清理所有临时文件和代理进程
- 不修改用户级 `.claude/settings.json`
- 不写入任何持久化环境变量

## 免责声明

本项目仅供学习研究。请遵守 TokenRhythm 服务条款。使用前请替换为自己的 API Key。