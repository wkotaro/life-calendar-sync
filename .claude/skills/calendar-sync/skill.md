---
name: calendar-sync
description: "カレンダー同期のカテゴリ管理（追加・削除・一覧）と手動同期。例: /calendar-sync list, /calendar-sync add, /calendar-sync remove, /calendar-sync sync"
argument-hint: "[add | remove | list | sync]"
allowed-tools: Bash, Read, Edit, AskUserQuestion
---

# Calendar Sync スキル

このリポジトリ（Life Calendar Sync）のカテゴリ管理と同期実行を行う。

## 定数

- CONFIG: `$CLAUDE_PROJECT_DIR/config.json`
- SYNC_SCRIPT: `$CLAUDE_PROJECT_DIR/sync.sh`
- ADD_SCRIPT: `$CLAUDE_PROJECT_DIR/add-category.sh`
- SYNC_LOG: `$CLAUDE_PROJECT_DIR/sync.log`
- ACCOUNT: config.json の `.account` を使う

## 引数の解釈

`$ARGUMENTS` を以下のように解釈する:

- **`list`** → 現在のカテゴリ一覧と各カレンダーの予定数を表示
- **`add`** → 対話的に新しいカテゴリを追加
- **`remove`** → 対話的にカテゴリを削除
- **`sync`** → sync.sh を手動実行
- **引数なし** → 使い方のヘルプとカテゴリ一覧を表示

## 動作: list

1. config.json を Read で読み込む
2. 各カテゴリについて、gogcli でイベント数を取得する:
   ```bash
   gog calendar events "<calendar_id>" -a "<account>" --days 30 -p 2>/dev/null | tail -n +2 | wc -l
   ```
3. 以下のフォーマットで表示:

```
## カレンダー同期 カテゴリ一覧

| # | キー | 名前 | 予定数（30日） |
|---|------|------|--------------|
| 1 | weather | 天気予報 | 7件 |
| 2 | public | 公的手続き | 3件 |
...

同期スケジュール: 毎日 6:00（launchd）
```

## 動作: add

1. AskUserQuestion で以下を聞く:
   - カテゴリキー（英数字、例: sports, movies）
   - カテゴリ名（日本語、例: スポーツ、映画公開日）
   - 取得する情報の説明（Claudeへのプロンプトになる）
   - summaryの例（カレンダーに表示される形式の例）

2. 入力内容を確認表示し、AskUserQuestion で「この内容で追加しますか？」と確認

3. 確認後、add-category.sh を実行:
   ```bash
   "$CLAUDE_PROJECT_DIR/add-category.sh" "<キー>" "<名前>" "<プロンプト>" "<summary例>"
   ```

4. 結果を表示（成功/失敗、カレンダーID）

5. AskUserQuestion で「今すぐ同期を実行しますか？」と確認し、「はい」なら sync.sh を実行

## 動作: remove

1. config.json を Read で読み込む
2. AskUserQuestion でカテゴリ一覧を選択肢として表示し、削除するカテゴリを選ばせる
3. 選択されたカテゴリの予定をすべて削除:
   ```bash
   # イベントIDを取得して全削除
   gog calendar events "<calendar_id>" -a "<account>" --days 120 -p 2>/dev/null | tail -n +2 | awk -F'\t' '{print $1}' | while read id; do
     gog calendar delete "<calendar_id>" "$id" -a "<account>" -y 2>/dev/null
   done
   ```
4. config.json からカテゴリを削除:
   ```bash
   jq 'del(.categories.<key>)' "$CLAUDE_PROJECT_DIR/config.json" > "$CLAUDE_PROJECT_DIR/config.json.tmp" \
     && mv "$CLAUDE_PROJECT_DIR/config.json.tmp" "$CLAUDE_PROJECT_DIR/config.json"
   ```
5. 結果を表示
   - 注意: Googleカレンダー自体（カレンダーの器）は削除しない。予定だけ削除し、config.json から外す。カレンダー自体の削除が必要な場合はGoogle Calendar UIから行うよう案内する

## 動作: sync

1. 「同期を実行します。1-2分かかります。」と表示
2. sync.sh を実行:
   ```bash
   "$CLAUDE_PROJECT_DIR/sync.sh"
   ```
   - タイムアウト: 5分（300000ms）
3. sync.log の最新の実行結果（最後の "=== Life Calendar Sync 開始 ===" 以降）を読み取って結果を表示:

```
## 同期完了

| カテゴリ | 登録件数 |
|---------|---------|
| 天気予報 | 7件 |
| 公的手続き | 3件 |
...

合計: N件登録（M件重複スキップ）
```

## 動作: 引数なし

以下を表示し、その後 list と同じカテゴリ一覧を表示する:

```
## /calendar-sync の使い方

| コマンド | 動作 |
|---------|------|
| /calendar-sync list | カテゴリ一覧と予定数を表示 |
| /calendar-sync add | 新しいカテゴリを追加 |
| /calendar-sync remove | カテゴリを削除 |
| /calendar-sync sync | 手動で同期を実行 |
```

## ルール

- gogcli のアカウントは config.json の `.account` を必ず使う
- カテゴリキーは英数字のみ（ハイフン、アンダースコアOK）
- 破壊的操作（削除、同期）は必ず確認を取ってから実行する
- sync.sh の実行はタイムアウトを300000ms（5分）に設定する
- エラーが出た場合は sync.log の内容を確認して原因を報告する
