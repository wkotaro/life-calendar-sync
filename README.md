# Life Calendar Sync

毎朝自動で生活に関わる情報を収集し、Googleカレンダーに登録するツール。

Claude Code（Sonnet）が情報を調べ、[gogcli](https://github.com/steipete/gogcli) でカレンダーに書き込む。

## 仕組み

```
launchd (毎朝6:00)
  -> sync.sh
       -> Claude Code (情報収集・JSON出力)
       -> gogcli (カレンダー登録)
```

1. 各カテゴリの既存予定を削除
2. Claude Code にプロンプトを送り、情報をJSON形式で取得
3. JSONをパースしてカテゴリごとのGoogleカレンダーに終日予定として登録
4. 同日の重複エントリは自動スキップ

## カテゴリ

`config.json` で管理。カテゴリごとに専用のGoogleカレンダーが作られる。

| キー | 名前 | 内容 |
|------|------|------|
| weather | 天気予報 | 名古屋の1週間天気（気温付き） |
| public | 公的手続き | 税金・選挙等の締切（3ヶ月先まで） |
| events | 催事・イベント | 愛知県周辺の物産展等（1ヶ月先まで） |
| sales | セール情報 | Amazon・楽天のセール（1ヶ月先まで） |
| anime | アニメ更新日 | PrimeVideo配信スケジュール（1ヶ月先まで） |

## 必要なもの

- [gogcli](https://github.com/steipete/gogcli) -- Google Calendar操作
- [Claude Code](https://claude.ai/code) (`claude` CLI) -- 情報収集
- jq -- JSON処理
- Googleアカウント（gogcli で認証済み）

## セットアップ

```bash
# gogcli の認証
gog auth credentials ~/Downloads/client_secret_....json
gog auth add you@gmail.com

# 動作確認
./sync.sh
```

## 定期実行（launchd）

```bash
# plist をインストール
cp com.lifesync.calendar.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.lifesync.calendar.plist

# 状態確認
launchctl list | grep lifesync

# 手動実行
launchctl start com.lifesync.calendar
```

## カテゴリの追加・削除

Claude Code のスキルから操作できる:

```
/calendar-sync list      # 一覧表示
/calendar-sync add       # カテゴリ追加
/calendar-sync remove    # カテゴリ削除
/calendar-sync sync      # 手動同期
```

またはシェルスクリプトで直接追加:

```bash
./add-category.sh <キー> <名前> <プロンプト> <summary例>

# 例
./add-category.sh sports "スポーツ" \
  "名古屋グランパス・中日ドラゴンズの今後1ヶ月の試合日程" \
  "グランパス vs 浦和 豊田スタジアム"
```

## ファイル構成

```
life-calendar-sync/
  config.json                    # カテゴリ設定（カレンダーID・プロンプト）
  sync.sh                        # メイン同期スクリプト
  add-category.sh                # カテゴリ追加スクリプト
  com.lifesync.calendar.plist    # launchd 定期実行設定
  sync.log                       # 実行ログ
  docs/prd/                      # 設計ドキュメント
```

## ログ

実行ログは `sync.log` に追記される:

```
[2026-04-26 11:06:04] === Life Calendar Sync 開始 ===
[2026-04-26 11:06:04] 既存予定を削除中...
[2026-04-26 11:10:03]   天気予報: 7件
[2026-04-26 11:10:34] === Life Calendar Sync 完了 (合計 28 件中 0 件重複スキップ, 28 件登録) ===
```
