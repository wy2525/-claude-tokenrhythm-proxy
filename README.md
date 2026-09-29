# claude-code-gateway | Claude Code 任意网关一键直连工具

> **让任意 Anthropic 兼容网关跑通任意版本的 Claude Code！** 自动检测环境、配置 API Key 与模型、启动本地协议清洗代理。解决 Claude Code 接入 TokenRhythm（基元律动）、DeepSeek 官方、GLM、自建网关等国内/第三方服务时的 `anthropic-beta` 400 报错、模型不识别、登录拦截等问题。**新旧版本 Claude Code 通吃**，支持多提供商配置一键切换，图形界面 + 命令行双模式，开箱即用。

## 📌 关键词

`Claude Code` `网关` `本地代理` `协议转换` `anthropic-beta 400` `TokenRhythm` `基元律动` `DeepSeek` `GLM` `Kimi` `Qwen` `第三方API` `中转站` `国内配置` `一键安装` `Windows` `PowerShell` `CC Switch 替代` `Claude Code 报错` `模型目录校验`

---

## 🎯 这个工具解决什么问题？

**一句话：不管你用哪家网关、哪个版本的 Claude Code，都能一键跑通。**

用 **Claude Code** 接入**非 Anthropic 官方**的网关（国内中转站、模型聚合平台、自建网关）时，几乎必然遇到以下问题：

### 问题 1：HTTP 400 报错（协议不兼容）

Claude Code（尤其新版）发送的请求带大量网关不认识的字段，导致 **HTTP 400**：

| 违禁字段 | 位置 | 后果 |
| --- | --- | --- |
| `anthropic-beta` | 请求头 | 400 |
| `thinking` / `output_config` / `context_management` / `service_tier` | 顶层字段 | 400 |
| `thinking` / `redacted_thinking` block | messages[] | 400 |
| `cache_control` | 每个 block | 400 |
| `role: "system"` 混在消息列表里 | messages[] | 400 |
| tool_use / tool_result 的扩展字段 | messages[] / tools[] | 400 |

> 网关的校验逻辑很朴素：多一个字段，拒一个请求。这不是 bug，是协议代差。

### 问题 2：新版 Claude Code 的模型目录校验

**Claude Code 2.1.283+** 会对模型名做目录校验，自定义模型名（如 `deepseek-flash`）不在其内置列表，会提示 `isn't described by this version's model catalog`。

> 好消息：这个校验**不拦截请求**，只是上下文窗口估算的警告。本工具已自动设置 `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1` 消除该警告。

### 问题 3：认证方式差异

不同版本对 `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY` 的处理不同，部分配置组合会触发登录提示。本工具使用实测可行的认证组合，新旧版本均免登录。

### 问题 4：换网关/换 Key 要改配置文件

手动改 `settings.json` 容易改错、互相覆盖。本工具支持**多提供商配置档案**，UI 里切换提供商即换 Key/模型，互不干扰。

---

## ✅ 本工具的解决方案

在本地 `127.0.0.1` 架一个**协议清洗代理**，把 Claude Code 的请求「翻译」成网关认识的格式再转发：

```
Claude Code ──→ http://127.0.0.1:<随机端口> ──→ 任意网关
                    │                            （TokenRhythm / DeepSeek / 自建）
                    └─ 本地清洗代理：
                       - 删除 anthropic-beta 请求头
                       - system 消息移到顶层
                       - 删除 thinking / cache_control / service_tier 等字段
                       - 自动处理 BaseURL 路径前缀（/v1、/anthropic 等）
```

---

## ✨ 功能特性

- ✅ **环境自动检测** — 检查 Node.js / Git / Claude Code 及版本是否就绪
- ✅ **版本无关** — 新版（2.1.283+）与旧版均支持，安装脚本可装最新版或指定版本
- ✅ **引导式配置** — 输入 API Key、选择模型，配置保存到本地
- ✅ **本地清洗代理** — 自动过滤不兼容字段，解决 400 报错
- ✅ **工作目录选择** — 图形界面可选 Claude Code 打开目录
- ✅ **自动清理** — 退出后自动清理临时文件和代理进程
- ✅ **安全设计** — Key 保存在本地 `.local-config.json`，gitignore 排除，不泄露
- ✅ **双模式** — 命令行脚本 + 图形界面 (GUI)
- ✅ **全中文教程** — 适合新手

---

## 📂 项目结构

```
cc-env-setup/
├── LaunchUI.bat          # 双击打开图形界面（推荐）
├── setup.bat             # 双击打开命令行菜单
├── Launcher.ps1          # 图形界面主程序
├── setup.ps1             # 命令行主菜单
└── scripts/
    ├── 01-check-env.ps1  # 环境检查
    ├── 02-install-cc.ps1 # 安装/降级 Claude Code
    ├── 03-config.ps1     # 配置 Key/模型
    └── 04-start.ps1      # 一键启动（本地代理 + Claude Code）
```

---

## 🚀 快速开始

### 方式一：图形界面（推荐，最简单）

1. **双击** `LaunchUI.bat`，打开图形界面
2. 按顺序操作，界面按钮及**正确显示结果**：

| 按钮 | 操作 | ✅ 正确显示结果 |
| --- | --- | --- |
| **Check Env** | 点击 | 弹出新窗口，显示 `[OK] Node.js...`、`[OK] Git...`、`[OK] Claude Code...`，**窗口停留** |
| **Install** | 点击 | 弹出新窗口，显示安装进度，最后 `Install succeeded!`，**窗口停留** |
| **Config Key** | 点击 | 弹出新窗口，输入 API Key → 选模型 → 显示 `配置已保存`，**窗口停留** |
| **Start Claude Code** | 点击 | 打开 Claude Code 终端，可正常对话 |

> 💡 **注意**：点击 Check Env / Install / Config Key 后会打开新窗口显示结果，**该窗口会停留**（不会闪退），看完手动关闭即可。

3. **推荐操作顺序**：
   - ① 点 **Check Env** → 看到 `[OK]` 即环境就绪
   - ② 点 **Install** → 安装/降级 Claude Code
   - ③ 点 **Config Key** → 配置 API Key 和模型
   - ④ 用 **Browse...** 选择工作目录
   - ⑤ 点 **Start Claude Code** → 启动

### 方式二：命令行

双击 `setup.bat` 打开菜单，或直接运行各脚本：

```powershell
# 1. 环境检查
powershell -ExecutionPolicy Bypass -File scripts\01-check-env.ps1

# 2. 安装/降级 Claude Code
powershell -ExecutionPolicy Bypass -File scripts\02-install-cc.ps1

# 3. 配置 Key/模型
powershell -ExecutionPolicy Bypass -File scripts\03-config.ps1

# 4. 一键启动（本地代理 + Claude Code）
powershell -ExecutionPolicy Bypass -File scripts\04-start.ps1
```

### 命令行直接启动（带参数）

```powershell
# 指定模型和工作目录
powershell -ExecutionPolicy Bypass -File scripts\04-start.ps1 -Model "deepseek-flash" -WorkDir "E:\你的项目目录"
```

**参数说明：**
| 参数 | 说明 | 默认值 |
| --- | --- | --- |
| `-Model` | 使用的模型 | 读取本地配置 |
| `-WorkDir` | Claude Code 工作目录 | 当前目录 |

---

## 🛠 环境要求

- **Windows 10 / 11**
- **Node.js 18+**（脚本会自动检测）
- **Git**（可选，脚本会自动检测）

---

## 🧠 支持的模型

仅支持 `supports_anthropic: true` 的模型（可通过网关 `/v1/models` 查询）：

| 模型 | 说明 |
| --- | --- |
| `deepseek-flash` | DeepSeek 快速模型（推荐） |
| `glm-5.3-flashx` | 智谱 GLM 快速模型 |
| `deepseek-v4-pro-0813` | DeepSeek 专业模型 |
| `mimo-v2.6-pro` | Mimo 专业模型 |

> 模型名可自由输入（UI 中 Model 下拉框可直接键入）。

---

## 🔌 多提供商支持（TokenRhythm / DeepSeek 官方 / 自定义网关）

UI 支持配置多个提供商，每个提供商独立保存自己的 Key 和模型，随时切换：

| 提供商 | BaseURL 预设 | 常用模型 |
| --- | --- | --- |
| **TokenRhythm**（基元律动） | `https://tokenrhythm.studio/v1` | `deepseek-flash`、`glm-5.3-flashx` 等 |
| **DeepSeek 官方** | `https://api.deepseek.com/anthropic` | `deepseek-chat`、`deepseek-reasoner` |
| **Custom**（自定义） | 任意 Anthropic 兼容网关地址 | 任意模型名 |

**使用方法：**
1. 在 UI 的 **Provider** 下拉框选择提供商（BaseURL 自动填充预设）
2. 填入该提供商的 API Key 和模型名
3. 点 **Save Config**（每个提供商的配置独立保存）
4. 切换提供商时，其配置自动加载，直接 Start 即可

**配置文件格式**（`.local-config.json`，多档案）：

```json
{
  "active": "tokenrhythm",
  "profiles": {
    "tokenrhythm": { "baseUrl": "https://tokenrhythm.studio/v1", "apiKey": "sk_tr_xxx", "model": "deepseek-flash" },
    "deepseek":    { "baseUrl": "https://api.deepseek.com/anthropic", "apiKey": "sk-xxx", "model": "deepseek-chat" }
  }
}
```

> 本地清洗代理会自动处理 BaseURL 的路径前缀（如 `/v1`、`/anthropic`），无需关心转发细节。

---

## 🔒 安全说明

- **API Key 不写入脚本**，保存在本地 `.local-config.json`（已被 `.gitignore` 排除，不会推送到公开仓库）
- 启动时使用**临时配置**，**不修改**用户级 `.claude/settings.json`
- **不写入**任何持久化环境变量
- 退出 Claude Code 后**自动清理**所有临时文件和代理进程

---

## 💡 常见问题 (FAQ)

**Q: 为什么需要降级 Claude Code？**
A: 两个版本都能用！最新版（2.1.283+）由清洗代理自动处理协议差异，工具还会自动禁用模型目录校验警告；旧版 2.1.153 也直接可用。安装脚本默认装最新版，也可 `-Version 2.1.153` 装旧版作为备用。

**Q: API Key 存在哪里？**
A: `scripts/../.local-config.json`，已被 gitignore 排除，不会推送到公开仓库。

**Q: 提示 `anthropic-beta` 400 报错怎么办？**
A: 本工具的本地清洗代理会自动删除 `anthropic-beta` 请求头，无需手动处理。

**Q: 提示模型 not found / 不认识怎么办？**
A: 确认使用上述「支持的模型」列表中的模型。若仍报错，检查 API Key 余额（402 余额不足也会显示为模型错误）。

**Q: 支持其他网关吗？**
A: 可修改 `scripts/04-start.ps1` 顶部的 `UPSTREAM` 地址指向其他网关。

**Q: 点击按钮闪退/窗口关闭怎么办？**
A: 已修复。点击 Check Env / Install / Config Key 后窗口会停留，请确认使用的是最新版。

---

## 📝 免责声明

本项目仅供学习研究。请遵守 **TokenRhythm（基元律动）** 服务条款。请使用自己的 API Key。

---

## 📄 License

MIT

---

## ⭐ 支持

如果这个工具对你有帮助，欢迎 **Star** ⭐ 支持！也欢迎提交 Issue 和 PR。