# heads-up

逃すと損する情報を、毎朝カレンダーに届ける。

## 例

朝起きてカレンダーを見ると、heads-up が教えてくれている:

- 「Amazon スマイルセール 明後日から（4/30〜5/3）」
- 「自動車税 納付期限まであと35日（6/1）」
- 「初夏の大北海道物産展 松坂屋名古屋 今日から（〜5/11）」

知ってれば行動できる。知らなければ逃す。
heads-up は、そういう情報を毎朝カレンダーに届ける。

## 仕組み

Claude Code（Sonnet）が情報を調べ、[gogcli](https://github.com/steipete/gogcli) でGoogle Calendarに書き込む。

```
毎朝6:00（launchd）
  -> sync.sh
       -> Claude Code（情報収集 → JSON出力）
       -> gogcli（カレンダー登録）
```

1. 各カテゴリの既存予定を削除
2. Claude Code にプロンプトを送り、情報をJSON形式で取得
3. カテゴリごとのGoogle Calendarに終日予定として登録
4. 同日の重複は自動スキップ

## カテゴリ

カテゴリは自分で自由に設定できる。`add-category.sh` で追加すると、対応するGoogle Calendarが自動作成される。

**「期限があり、逃すと損する情報」に向いている:**

| キー | 名前 | プロンプト例 |
|------|------|-------------|
| sales | セール情報 | 「Amazon・楽天の主要セール日程」 |
| public | 公的手続き | 「3ヶ月以内に締切がある税金・行政手続き」 |
| events | 催事・イベント | 「周辺の期間限定イベント・物産展」 |
| movies | 映画公開日 | 「今後1ヶ月の注目映画の公開日」 |
| tickets | チケット発売 | 「好きなアーティストのチケット発売日」 |

プロンプトの内容次第でどんな情報でも収集できるが、heads-up が力を発揮するのは**「知らなければ逃す」タイプの情報**。

## 必要なもの

- [gogcli](https://github.com/steipete/gogcli) -- Google Calendar操作
- [Claude Code](https://claude.ai/code) (`claude` CLI) -- 情報収集（Max または有料プランが必要）
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
chmod +x sync.sh add-category.sh
```

`config.json` の `account` を gogcli で認証したメールアドレスに変更する:

```json
{
  "account": "you@gmail.com",
  "categories": {}
}
```

### 4. カテゴリを追加

`add-category.sh` でカテゴリを追加する。Google Calendarの作成と config.json への追記が自動で行われる。

```bash
./add-category.sh sales "セール情報" \
  "今日から1ヶ月以内に予定されているAmazon・楽天の主要セール\n- 開始日で登録し、summaryに期間を含める\n- 該当するものだけ出力" \
  "Amazonタイムセール祭り（5/10〜5/12）"
```

```bash
./add-category.sh public "公的手続き" \
  "今日から3ヶ月以内に締切がある主要な行政手続き（税金等）\n- 該当するものだけ出力" \
  "自動車税 納付期限"
```

```bash
./add-category.sh events "催事・イベント" \
  "周辺の今後1ヶ月以内の期間限定イベント・物産展\n- 該当するものだけ出力" \
  "北海道物産展 松坂屋名古屋（〜5/11）"
```

### 5. 動作確認

```bash
./sync.sh
```

初回実行には1-2分かかる（Claude Code による情報収集のため）。

## 定期実行（macOS launchd）

plist 内のパスを自分の環境に合わせて編集してからインストールする:

```bash
# plist 内のパスを書き換え
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

cron や Claude Code の `/schedule` でも代用できる。

## カテゴリの追加

```bash
./add-category.sh <キー> <名前> <プロンプト> <summary例>
```

Google Calendarの作成と config.json への追記が自動で行われる。

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
