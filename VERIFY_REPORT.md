# 検証レポート: life-calendar-sync (heads-up)

_検証日: 2026-04-26_

結果: **PASS**

## 1. 静的チェック

| # | チェック項目 | 結果 | 詳細 |
|---|-------------|------|------|
| 1 | 個人情報の漏れ | OK | メールは全て `you@gmail.com`（プレースホルダ）。長いハッシュ文字列なし。VERIFY_REPORT.md 内の `/Users/yourname` は前回レポートの引用のみ |
| 2 | プレースホルダの残留 | WARN | plist に `{{PROJECT_DIR}}` `{{HOME}}` あり。README に sed で書き換える手順が記載されており意図的 |
| 3 | 必要ファイルの存在 | OK | README.md, sync.sh, add-category.sh, config.example.json, com.lifesync.calendar.plist, .gitignore 全て存在 |
| 4 | .gitignore の内容 | OK | config.json（機密）, sync.log, launchd-stdout.log, launchd-stderr.log を除外済み |

## 2. ドキュメントチェック

| # | チェック項目 | 結果 | 詳細 |
|---|-------------|------|------|
| 1 | セットアップ手順 | OK | 「セットアップ」セクションあり。5ステップで明確 |
| 2 | 手順の矛盾 | OK | README で参照している config.example.json, sync.sh, add-category.sh, com.lifesync.calendar.plist は全て存在。config.json は `cp` で作成する手順あり |
| 3 | 依存ツールの明記 | OK | gog（gogcli）、claude（Claude Code）、jq を「必要なもの」に記載 |

## 3. 論理チェック

| # | チェック項目 | 結果 | 詳細 |
|---|-------------|------|------|
| 1 | ファイル参照の整合性 | OK | sync.sh が参照する config.json は `cp config.example.json config.json` で作成。sync.log はスクリプト自身が生成 |
| 2 | 設定テンプレートの妥当性 | OK | config.example.json は空カテゴリ（`"categories": {}`）。ダミーIDなし。add-category.sh で追加する手順を案内済み。config.json は .gitignore に含まれている |
| 3 | スクリプト間の依存 | OK | sync.sh と add-category.sh は独立。両方とも config.json のみを共有し、互いを直接参照しない |

## 修正提案

FAIL なし。以下は改善の余地がある点:

1. **WARN: plist のプレースホルダ** -- README に sed コマンドの手順があり問題なし（優先度: 低）
2. **NOTE: README タイトルが `heads-up` だがリポジトリ名は `life-calendar-sync`** -- リポジトリ名の変更を検討してもよい（優先度: 低、GitHub の Settings > Rename で変更可能）
