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

`config.json` で管理。カテゴリごとに専用のGoogleカレンダーが作られる。カテゴリは自由に追加できる。

### 設定例

| キー | 名前 | 内容 |
|------|------|------|
| weather | 天気予報 | 1週間天気（気温付き） |
| public | 公的手続き | 税金・選挙等の締切（3ヶ月先まで） |
| events | 催事・イベント | 周辺の物産展等（1ヶ月先まで） |
| sales | セール情報 | Amazon・楽天のセール（1ヶ月先まで） |
| anime | アニメ更新日 | 動画配信の更新スケジュール（1ヶ月先まで） |

## 必要なもの

- [gogcli](https://github.com/steipete/gogcli) -- Google Calendar操作
- [Claude Code](https://claude.ai/code) (`claude` CLI) -- 情報収集
- jq -- JSON処理
- Googleアカウント（gogcli で認証済み）

## セットアップ

### 1. リポジトリをクローン

```bash
git clone https://github.com/wkotaro/life-calendar-sync.git
cd life-calendar-sync
```

### 2. gogcli の認証

```bash
gog auth credentials ~/Downloads/client_secret_....json
gog auth add you@gmail.com
```

Google Cloud Console で OAuth2 クレデンシャルを作成し、Calendar API を有効化しておく。詳細は [gogcli の README](https://github.com/steipete/gogcli) を参照。

### 3. config.json を作成

```bash
cp config.example.json config.json
```

`config.json` を開いて以下を編集する:

- `account`: gogcli で認証したメールアドレス
- 各カテゴリの `calendar_id`: `add-category.sh` で自動作成される（下記参照）
- 各カテゴリの `prompt`: Claude に渡す情報収集の指示
- 各カテゴリの `summary_example`: カレンダーに表示される形式の例

最初のカテゴリは `add-category.sh` で追加するのが簡単:

```bash
chmod +x sync.sh add-category.sh

./add-category.sh weather "天気予報" \
  "東京の今日から1週間分の天気予報\n- 日付、天気、最高気温、最低気温" \
  "晴れ 25℃/14℃ 東京"
```

これで Google カレンダーが自動作成され、config.json にカテゴリが追加される。

### 4. 動作確認

```bash
./sync.sh
```

初回実行には1-2分かかる（Claude Code による情報収集のため）。

## 定期実行（macOS launchd）

plist 内のパスを自分の環境に合わせて編集してからインストールする:

```bash
# plist 内のパスを書き換え（例: /Users/yourname/life-calendar-sync）
sed -i '' "s|{{PROJECT_DIR}}|$(pwd)|g" com.lifesync.calendar.plist
sed -i '' "s|{{HOME}}|$HOME|g" com.lifesync.calendar.plist

# インストール
cp com.lifesync.calendar.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.lifesync.calendar.plist

# 状態確認
launchctl list | grep lifesync

# 手動実行
launchctl start com.lifesync.calendar
```

## カテゴリの追加

```bash
./add-category.sh <キー> <名前> <プロンプト> <summary例>

# 例
./add-category.sh sports "スポーツ" \
  "今後1ヶ月の地元チームの試合日程" \
  "チーム名 vs 対戦相手 スタジアム名"
```

Googleカレンダーの作成と config.json への追記が自動で行われる。

## ファイル構成

```
life-calendar-sync/
  config.example.json              # 設定テンプレート（コピーして config.json を作成）
  config.json                      # カテゴリ設定（.gitignore 対象）
  sync.sh                          # メイン同期スクリプト
  add-category.sh                  # カテゴリ追加スクリプト
  com.lifesync.calendar.plist      # launchd 定期実行設定
  sync.log                         # 実行ログ（.gitignore 対象）
```

## ログ

実行ログは `sync.log` に追記される:

```
[2026-04-26 11:06:04] === Life Calendar Sync 開始 ===
[2026-04-26 11:06:04] 既存予定を削除中...
[2026-04-26 11:10:03]   天気予報: 7件
[2026-04-26 11:10:34] === Life Calendar Sync 完了 (合計 28 件中 0 件重複スキップ, 28 件登録) ===
```
