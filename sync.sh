#!/bin/bash
set -euo pipefail

# heads-up - 逃すと損する情報を毎朝カレンダーに届ける
# 使い方: ./sync.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
LOG_FILE="${SCRIPT_DIR}/sync.log"
TODAY=$(date +%Y-%m-%d)

ACCOUNT=$(jq -r '.account' "$CONFIG_FILE")
PROFILE=$(jq -r '.profile // empty' "$CONFIG_FILE")
CATEGORY_KEYS=$(jq -r '.categories | keys[]' "$CONFIG_FILE")

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 指定カレンダーの全予定を削除（広い日付範囲で確実に取得）
clear_calendar() {
  local cal_id="$1"
  local cal_name="$2"
  log "  ${cal_name} の既存予定を削除中..."
  local event_ids
  event_ids=$(gog calendar events "$cal_id" -a "$ACCOUNT" --days 120 -p 2>/dev/null | tail -n +2 | awk -F'\t' '{print $1}')

  if [ -n "$event_ids" ]; then
    while IFS= read -r event_id; do
      if [ -n "$event_id" ]; then
        gog calendar delete "$cal_id" "$event_id" -a "$ACCOUNT" -y 2>/dev/null && \
          log "    削除: $event_id" || \
          log "    削除失敗: $event_id"
      fi
    done <<< "$event_ids"
  else
    log "    削除対象なし"
  fi
}

log "=== heads-up 開始 ==="

# ステップ1: 全カレンダーの既存予定を削除
log "既存予定を削除中..."
while IFS= read -r key; do
  cal_id=$(jq -r ".categories.${key}.calendar_id" "$CONFIG_FILE")
  cal_name=$(jq -r ".categories.${key}.name" "$CONFIG_FILE")
  clear_calendar "$cal_id" "$cal_name"
done <<< "$CATEGORY_KEYS"

# ステップ2: 設定ファイルからプロンプトを組み立て
log "Claude Code で情報収集中..."

PROMPT="あなたは情報収集アシスタントです。以下の情報を調べて、指定されたJSON形式で出力してください。
余計な説明は一切不要です。JSONのみを出力してください。
"

if [ -n "$PROFILE" ]; then
  PROMPT="${PROMPT}
## この人のプロフィール
${PROFILE}
"
fi

PROMPT="${PROMPT}
## 調べる情報
"

OUTPUT_FORMAT="{"
EXAMPLES=""
idx=1
while IFS= read -r key; do
  cat_name=$(jq -r ".categories.${key}.name" "$CONFIG_FILE")
  cat_prompt=$(jq -r ".categories.${key}.prompt" "$CONFIG_FILE" | sed "s/{today}/${TODAY}/g")
  cat_example=$(jq -r ".categories.${key}.summary_example" "$CONFIG_FILE")

  PROMPT="${PROMPT}
${idx}. **${cat_name}**:
${cat_prompt}
"
  if [ "$idx" -gt 1 ]; then
    OUTPUT_FORMAT="${OUTPUT_FORMAT},"
  fi
  OUTPUT_FORMAT="${OUTPUT_FORMAT}
  \"${key}\": [{\"date\": \"YYYY-MM-DD\", \"summary\": \"...\"}]"
  EXAMPLES="${EXAMPLES}
${key} の summary 例: \"${cat_example}\""
  idx=$((idx + 1))
done <<< "$CATEGORY_KEYS"

OUTPUT_FORMAT="${OUTPUT_FORMAT}
}"

PROMPT="${PROMPT}
## 出力形式（厳密にこのJSON形式で）

\`\`\`json
${OUTPUT_FORMAT}
\`\`\`
${EXAMPLES}
"

RESPONSE=$(claude -p --model sonnet "$PROMPT" 2>/dev/null)

log "Claude Code 応答取得完了"

# ステップ3: JSONをパースしてカレンダーに登録
log "カレンダーに登録中..."

JSON_DATA=$(echo "$RESPONSE" | sed -n '/^```json/,/^```$/p' | sed '1d;$d')
if [ -z "$JSON_DATA" ]; then
  JSON_DATA=$(echo "$RESPONSE" | sed -n '/^{/,/^}/p')
fi

if [ -z "$JSON_DATA" ]; then
  log "エラー: JSONの抽出に失敗しました"
  log "応答内容: $RESPONSE"
  exit 1
fi

TOTAL=0
SKIPPED=0
while IFS= read -r key; do
  cal_id=$(jq -r ".categories.${key}.calendar_id" "$CONFIG_FILE")
  cal_name=$(jq -r ".categories.${key}.name" "$CONFIG_FILE")
  count=$(echo "$JSON_DATA" | jq -r ".${key} | length")

  # 重複チェック用: 登録済みの日付を一時ファイルに記録
  dedup_file=$(mktemp)

  log "  ${cal_name}: ${count}件"
  for i in $(seq 0 $((count - 1))); do
    event_date=$(echo "$JSON_DATA" | jq -r ".${key}[$i].date")
    event_summary=$(echo "$JSON_DATA" | jq -r ".${key}[$i].summary")
    event_end=$(date -j -f "%Y-%m-%d" -v+1d "$event_date" +%Y-%m-%d 2>/dev/null || date -d "$event_date + 1 day" +%Y-%m-%d)

    # 同じ日付に既に登録済みならスキップ（天気予報は1日1件、他も日付単位で重複防止）
    if grep -qx "$event_date" "$dedup_file" 2>/dev/null; then
      log "    スキップ（重複）: $event_date - $event_summary"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    echo "$event_date" >> "$dedup_file"

    gog calendar create "$cal_id" \
      --summary "$event_summary" \
      --from "$event_date" \
      --to "$event_end" \
      --all-day \
      -a "$ACCOUNT" \
      -y 2>/dev/null && \
      log "    登録: $event_date - $event_summary" || \
      log "    登録失敗: $event_date - $event_summary"
  done
  rm -f "$dedup_file"
  TOTAL=$((TOTAL + count))
done <<< "$CATEGORY_KEYS"

log "=== heads-up 完了 (合計 $TOTAL 件中 $SKIPPED 件重複スキップ, $((TOTAL - SKIPPED)) 件登録) ==="
