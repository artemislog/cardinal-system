#!/usr/bin/env bash
# CardinalSystem の無人巡回（macOS / Linux）。Claude Code を `claude -p` で1回起動し、cardinal-system スキルで巡回させる。
#
#   patrol.sh /path/to/project                 # 巡回
#   patrol.sh /path/to/project --report-only   # 観測のみ（修復しない）
#   patrol.sh /path/to/project --target "nightly-export が失敗する"
#   patrol.sh /path/to/project --dry-run       # 起動内容の確認だけ
#
# cron 例（毎日 18:00）:
#   0 18 * * * /path/to/patrol.sh /path/to/project >/dev/null 2>&1
#
# 追加で許可したいツールは環境変数 CARDINAL_ALLOW に空白区切りで（例: CARDINAL_ALLOW='Bash(cargo test*) Bash(make check*)'）
# 結果は <プロジェクト>/.cardinal/ledger.md（スキルが書く）と .cardinal/logs/<日時>.log（このスクリプトが書く）
set -euo pipefail

project="${1:?プロジェクトのパスを指定してください}"; shift || true
mode="巡回"; dry=0; report=0
while [ $# -gt 0 ]; do
  case "$1" in
    --report-only) mode="観測のみ（修復しない）"; report=1 ;;
    --target) shift; mode="スポット: ${1:?}" ;;
    --dry-run) dry=1 ;;
  esac
  shift
done
cd "$project"
command -v claude >/dev/null || { echo "claude（Claude Code CLI）が PATH にありません" >&2; exit 1; }

prompt="/cardinal-system ${mode}

無人の定期実行です。質問はできません。迷ったら直さずに記録して終えてください。
最後に .cardinal/ledger.md への追記を必ず行ってください。"

allowed=(Read Glob Grep TodoWrite Skill
  'Bash(git status*)' 'Bash(git diff*)' 'Bash(git log*)' 'Bash(git ls-files*)'
  'Bash(node --check*)' 'Bash(python -m py_compile*)' 'Bash(python3 -m py_compile*)' 'Bash(bash -n*)'
  'Bash(npm test*)' 'Bash(npm run test*)' 'Bash(npm run lint*)' 'Bash(npm run build*)' 'Bash(npx tsc --noEmit*)'
  'Bash(pytest*)' 'Bash(go test*)' 'Bash(go vet*)')
[ "$report" = 1 ] || allowed+=(Edit Write)
# shellcheck disable=SC2206
[ -n "${CARDINAL_ALLOW:-}" ] && allowed+=(${CARDINAL_ALLOW})
denied=('Bash(git push*)' 'Bash(git reset*)' 'Bash(git clean*)' 'Bash(git checkout -- *)' 'Bash(rm -rf*)' WebFetch WebSearch)
[ "$report" = 1 ] && denied+=(Edit Write)

args=(-p --output-format text --permission-mode acceptEdits --allowedTools "${allowed[@]}" --disallowedTools "${denied[@]}")
if [ "$dry" = 1 ]; then
  printf '作業フォルダ: %s\nプロンプト:\n%s\n起動: claude %s\n' "$project" "$prompt" "${args[*]}"; exit 0
fi

mkdir -p .cardinal/logs
log=".cardinal/logs/$(date +%Y%m%d_%H%M%S).log"
if command -v timeout >/dev/null; then t=(timeout "${CARDINAL_TIMEOUT:-45m}"); else t=(); fi
printf '%s' "$prompt" | ${t[@]+"${t[@]}"} claude "${args[@]}" >>"$log" 2>&1 || echo "[$(date '+%Y-%m-%dT%H:%M:%S')] 終了コード $?" >>"$log"
echo "[$(date '+%Y-%m-%dT%H:%M:%S')] 終了" >>"$log"
