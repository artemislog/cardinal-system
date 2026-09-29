<#
  CardinalSystem の無人巡回（Windows）。Claude Code を `claude -p` で1回起動し、cardinal-system スキルで巡回させる。
  タスクスケジューラに登録して定期実行する。

    powershell -NoProfile -ExecutionPolicy Bypass -File patrol.ps1 -Project C:\path\to\project
    powershell -NoProfile -ExecutionPolicy Bypass -File patrol.ps1 -Project C:\path\to\project -ReportOnly
    powershell -NoProfile -ExecutionPolicy Bypass -File patrol.ps1 -Project C:\path\to\project -Target "nightly-export が失敗する"
    powershell -NoProfile -ExecutionPolicy Bypass -File patrol.ps1 -Project C:\path\to\project -DryRun   # 起動内容の確認だけ

  登録例（毎日 18:00）:
    $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "<このファイル>" -Project "<プロジェクト>"'
    Register-ScheduledTask -TaskName 'CardinalSystem-Patrol' -Action $a -Trigger (New-ScheduledTaskTrigger -Daily -At 18:00)

  - 許可するツールは -AllowTools で足す（例: -AllowTools 'Bash(pytest*)','Bash(cargo test*)'）
  - 結果は <プロジェクト>\.cardinal\ledger.md（スキルが書く）と .cardinal\logs\<日時>.log（このスクリプトが書く）
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Project,
  [switch]$ReportOnly,
  [string]$Target,
  [string[]]$AllowTools = @(),
  [int]$TimeoutMinutes = 45,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$Project = (Resolve-Path -LiteralPath $Project).Path
$claude = (Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $claude) { throw 'claude（Claude Code CLI）が PATH にありません' }

$mode = if ($Target) { "スポット: $Target" } elseif ($ReportOnly) { '観測のみ（修復しない）' } else { '巡回' }
$prompt = @"
/cardinal-system $mode

無人の定期実行です。質問はできません。迷ったら直さずに記録して終えてください。
最後に .cardinal/ledger.md への追記を必ず行ってください。
"@

$allowed = @(
  'Read', 'Glob', 'Grep', 'Edit', 'Write', 'TodoWrite', 'Skill',
  'Bash(git status*)', 'Bash(git diff*)', 'Bash(git log*)', 'Bash(git ls-files*)',
  'Bash(node --check*)', 'Bash(python -m py_compile*)', 'Bash(bash -n*)',
  'Bash(npm test*)', 'Bash(npm run test*)', 'Bash(npm run lint*)', 'Bash(npm run build*)', 'Bash(npx tsc --noEmit*)',
  'Bash(pytest*)', 'Bash(go test*)', 'Bash(go vet*)'
) + $AllowTools
$denied = @('Bash(git push*)', 'Bash(git reset*)', 'Bash(git clean*)', 'Bash(git checkout -- *)', 'Bash(rm -rf*)', 'WebFetch', 'WebSearch')
if ($ReportOnly) { $denied += @('Edit', 'Write'); $allowed = $allowed | Where-Object { $_ -notin @('Edit', 'Write') } }
# Windows では Claude が PowerShell ツールでコマンドを出すことがあるので、同じ規則を付ける
$allowed += $allowed | Where-Object { $_ -like 'Bash(*' } | ForEach-Object { $_ -replace '^Bash\(', 'PowerShell(' }
$denied  += $denied  | Where-Object { $_ -like 'Bash(*' } | ForEach-Object { $_ -replace '^Bash\(', 'PowerShell(' }

$cargs = @('-p', '--output-format', 'text', '--permission-mode', 'acceptEdits', '--allowedTools') + $allowed + @('--disallowedTools') + $denied
if ($DryRun) {
  Write-Host "作業フォルダ: $Project"; Write-Host "プロンプト:`n$prompt"; Write-Host "起動: $claude $($cargs -join ' ')"; return
}

$logDir = Join-Path $Project '.cardinal\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ((Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')

Push-Location $Project
try {
  $job = Start-Job -ScriptBlock { param($exe, $a, $p, $dir)
    # 5.1 はパイプの既定が ASCII で日本語のプロンプトが化けるため UTF-8 にする
    $OutputEncoding = [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    Set-Location $dir; $p | & $exe @a 2>&1 } -ArgumentList $claude, $cargs, $prompt, $Project
  if (-not (Wait-Job $job -Timeout ($TimeoutMinutes * 60))) {
    Stop-Job $job; "[$(Get-Date -Format s)] ${TimeoutMinutes}分で打ち切り" | Out-File $log -Encoding utf8 -Append
    exit 1
  }
  Receive-Job $job | Out-File $log -Encoding utf8 -Append
  "[$(Get-Date -Format s)] 終了" | Out-File $log -Encoding utf8 -Append
} finally { Pop-Location; Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue }
