# cc-env-setup | Claude Code 环境一键配置工具（TokenRhythm/基元律动/DeepSeek/GLM 本地代理）

> **一键搞定 Claude Code 国内配置！** 自动检测环境、安装/降级兼容版 Claude Code、配置 API Key、启动本地协议清洗代理。解决 Claude Code 接入 TokenRhythm（基元律动）、DeepSeek、GLM 等国内模型时的 `anthropic-beta` 400 报错、强制登录、模型不识别等问题。支持图形界面和命令行，开箱即用。

## 📌 关键词

`Claude Code` `TokenRhythm` `基元律动` `DeepSeek` `GLM` `本地代理` `协议转换` `anthropic-beta 400` `国内配置` `一键安装` `Windows` `PowerShell` `CC Switch` `Claude Code 报错`

---

## 🎯 这个工具解决什么问题？

国内使用 **Claude Code** 接入 **TokenRhythm（基元律动）** 等网关时，会遇到这些常见问题：

### 问题 1：HTTP 400 报错（协议不兼容）

Claude Code 新版发送请求时，会带以下 TokenRhythm 网关**不认识的字段**，导致 **HTTP 400**：

| 违禁字段 | 位置 | 后果 |
| --- | --- | --- |
| `anthropic-beta` | 请求头 | 400 |
| `thinking` / `output_config` / `context_management` / `service_tier` | 顶层字段 | 400 |
| `thinking` / `redacted_thinking` block | messages[] | 400 |
| `cache_control` | 每个 block | 400 |
| `role: "system"` 混在消息列表里 | messages[] | 400 |
| tool_use / tool_result 的扩展字段 | messages[] / tools[] | 400 |

### 问题 2：新版 Claude Code 强制登录

**Claude Code 2.1.283+** 会校验模型目录、强制要求登录，无法用 API Key 直连网关。需要**降级到 2.1.153**。

### 问题 3：不认识自定义模型名

新版 Claude Code 不认识 `deepseek-flash`、`glm-5.3-flashx` 等自定义模型名，提示 `isn't described by this version's model catalog`。

---

## ✅ 本工具的解决方案

在本地 `127.0.0.1` 架一个**协议清洗代理**，把 Claude Code 的请求「翻译」成网关认识的格式再转发：

```
Claude Code ──→ http://127.0.0.1:<随机端口> ──→ https://tokenrhythm.studio
                    │
                    └─ 本地清洗代理：
                       - 删除 anthropic-beta 请求头
                       - system 消息移到顶层
                       - 删除 thinking / cache_control / service_tier 等字段
```

---

## ✨ 功能特性

- ✅ **环境自动检测** — 检查 Node.js / Git / Claude Code 及版本是否就绪
- ✅ **一键降级** — 自动安装兼容版 Claude Code (2.1.153)
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
| **Install** | 点击 | 弹出新窗口，显示安装进度，最后 `Claude Code 2.1.153 安装成功`，**窗口停留** |
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
A: 新版 (2.1.283+) 会强制登录且不识别自定义模型名，旧版 **2.1.153** 可正常使用 API Key 直连。

**Q: API Key 存在哪里？**
A: `scripts/../.local-config.json`，已被 gitignore 排除，不会推送到公开仓库。

**Q: 提示 `anthropic-beta` 400 报错怎么办？**
A: 本工具的本地清洗代理会自动删除 `anthropic-beta` 请求头，无需手动处理。

**Q: 提示模型 not found / 不认识怎么办？**
A: 确认使用上述「支持的模型」列表中的模型，且 Claude Code 已降级到 2.1.153。

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