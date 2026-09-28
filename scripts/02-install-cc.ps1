# ============================================
# cc-env-setup | 瀹夎/闄嶇骇 Claude Code
# 瀹夎 2.1.153锛堝吋瀹圭増鏈級
# ============================================

param(
    [string]$Version = "2.1.153"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===== Claude Code 瀹夎/闄嶇骇 =====" -ForegroundColor Cyan
Write-Host "鐩爣鐗堟湰: $Version"
Write-Host ""

# 妫€鏌ュ綋鍓嶇増鏈?$current = (claude --version 2>&1).Trim()
Write-Host "褰撳墠鐗堟湰: $current"

if ($current -eq $Version) {
    Write-Host "[OK] 宸叉槸鏈€浣崇増鏈紝鏃犻渶鎿嶄綔" -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "寮€濮嬪畨瑁?Claude Code $Version ..." -ForegroundColor Yellow

# 灏濊瘯鍏ㄥ眬瀹夎
try {
    npm install -g "@anthropic-ai/claude-code@$Version" 2>&1 | Out-Host
} catch {
    Write-Host "[X] 瀹夎澶辫触锛屽彲鑳介渶瑕佺鐞嗗憳鏉冮檺" -ForegroundColor Red
    Write-Host "璇蜂互绠＄悊鍛樿韩浠芥墦寮€ PowerShell 鍚庨噸璇? -ForegroundColor Yellow
    exit 1
}

# 楠岃瘉
Write-Host ""
$newVersion = (claude --version 2>&1).Trim()
Write-Host "瀹夎鍚庣増鏈? $newVersion"

if ($newVersion -eq $Version) {
    Write-Host "[OK] Claude Code $Version 瀹夎鎴愬姛锛? -ForegroundColor Green
} else {
    Write-Host "[WARN] 鐗堟湰鍙兘鏈敓鏁堬紝璇烽噸鏂版墦寮€缁堢楠岃瘉" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== 瀹屾垚 ===" -ForegroundColor Cyan