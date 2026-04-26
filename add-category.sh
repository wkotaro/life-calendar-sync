#!/bin/bash
set -euo pipefail

# config.json に新しいカテゴリを追加し、対応するGoogleカレンダーも作成する
# 使い方: ./add-category.sh <キー> <名前> <プロンプト> <summary例>
# 例:    ./add-category.sh events "催事・イベント" "愛知県周辺の今後1ヶ月以内の催事・物産展・フェス情報" "北海道展 名古屋タカシマヤ"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

if [ $# -lt 4 ]; then
  echo "使い方: $0 <キー> <カレンダー名> <プロンプト> <summary例>"
  echo ""
  echo "例:"
  echo "  $0 events \"催事・イベント\" \"愛知県周辺の今後1ヶ月以内の催事・物産展情報\" \"北海道展 名古屋タカシマヤ\""
  echo "  $0 sports \"スポーツ\" \"今後1週間の名古屋グランパス・中日ドラゴンズの試合日程\" \"グランパス vs 浦和 豊田スタジアム\""
  echo ""
  echo "現在のカテゴリ:"
  jq -r '.categories | to_entries[] | "  \(.key): \(.value.name)"' "$CONFIG_FILE"
  exit 1
fi

KEY="$1"
NAME="$2"
PROMPT="$3"
EXAMPLE="$4"
ACCOUNT=$(jq -r '.account' "$CONFIG_FILE")

# 既存キーのチェック
if jq -e ".categories.${KEY}" "$CONFIG_FILE" > /dev/null 2>&1; then
  echo "エラー: キー '${KEY}' は既に存在します"
  exit 1
fi

# Googleカレンダーを作成
echo "Googleカレンダー「${NAME}」を作成中..."
CAL_OUTPUT=$(gog calendar create-calendar "$NAME" -a "$ACCOUNT" 2>&1)
CAL_ID=$(echo "$CAL_OUTPUT" | grep "^id" | awk -F'\t' '{print $2}')

if [ -z "$CAL_ID" ]; then
  echo "エラー: カレンダーの作成に失敗しました"
  echo "$CAL_OUTPUT"
  exit 1
fi

echo "カレンダーID: ${CAL_ID}"

# config.json に追加
jq --arg key "$KEY" \
   --arg name "$NAME" \
   --arg cal_id "$CAL_ID" \
   --arg prompt "$PROMPT" \
   --arg example "$EXAMPLE" \
   '.categories[$key] = {name: $name, calendar_id: $cal_id, prompt: $prompt, summary_example: $example}' \
   "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

echo ""
echo "追加完了:"
echo "  キー: ${KEY}"
echo "  名前: ${NAME}"
echo "  カレンダーID: ${CAL_ID}"
echo ""
echo "次回の sync.sh 実行時に反映されます。今すぐ反映するには:"
echo "  ./sync.sh"
