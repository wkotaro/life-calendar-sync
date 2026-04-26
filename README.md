# heads-up

逃すと損する情報を、毎朝カレンダーに届ける。

## 例

朝起きてカレンダーを見ると、heads-up が教えてくれている:

- 「Amazon スマイルセール 明後日から（4/30〜5/3）」
- 「自動車税 納付期限まであと35日（6/1）」
- 「初夏の大北海道物産展 松坂屋名古屋 今日から（〜5/11）」

そしてプロフィールに「アニメ・プログラミングが好き。登山・筋トレが趣味」と書いておくと、**普段は自分で調べないジャンル**からも:

- 「とよたガーデニングフェスタ 豊田市（無料エリアあり）」
- 「TOKAI ECO FESTA 碧南市（環境体験WS・マルシェ、入場無料）」

知ってれば行動できる。知らなければ逃す。
heads-up は、あなたのフィルターの外にある情報も含めて提案する。

## プロフィール

heads-up の特徴は、`config.json` に書いた自分のプロフィールに基づいてパーソナライズされること。

```json
{
  "profile": "東京在住の30代。映画とカフェ巡りが好き。スポーツはあまり見ない。"
}
```

プロフィールは全カテゴリの情報収集に影響するが、特に力を発揮するのが **discovery（発見）カテゴリ**。プロフィールの趣味や興味の**延長線上にないもの**を優先的に提案する。

「興味がない」と思い込んでいるだけで、知れば行きたくなるかもしれない。heads-up はそこを拾う。

## 仕組み

Claude Code（Sonnet）が情報を調べ、[gogcli](https://github.com/steipete/gogcli) でGoogle Calendarに書き込む。

```
毎朝6:00（launchd）
  -> sync.sh
       -> Claude Code（プロフィール + カテゴリで情報収集 -> JSON出力）
       -> gogcli（カレンダー登録）
```

1. 各カテゴリの既存予定を削除
2. プロフィールとカテゴリのプロンプトをClaude Codeに送信
3. カテゴリごとのGoogle Calendarに終日予定として登録
4. 同日の重複は自動スキップ

## カテゴリ

カテゴリは自分で自由に設定できる。`add-category.sh` で追加すると、対応するGoogle Calendarが自動作成される。

### 推奨カテゴリ

| キー | 名前 | 説明 |
|------|------|------|
| **discovery** | **発見** | **プロフィールの趣味の外にある期間限定イベント・体験（キラーフィーチャー）** |
| sales | セール情報 | Amazon・楽天の主要セール日程 |
| public | 公的手続き | 税金・行政手続きの締切 |
| events | 催事・イベント | 周辺の期間限定イベント・物産展 |

### その他のカテゴリ例

| キー | 名前 | プロンプト例 |
|------|------|-------------|
| movies | 映画公開日 | 「今後1ヶ月の注目映画の公開日」 |
| tickets | チケット発売 | 「好きなアーティストのチケット発売日」 |
| anime | アニメ更新日 | 「視聴中アニメの配信スケジュール」 |

heads-up が力を発揮するのは**「知らなければ逃す」タイプの情報**。

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

`config.json` を編集する:

```json
{
  "account": "you@gmail.com",
  "profile": "自分のことを自由に書く。住んでいる場所、趣味、興味、普段やらないこと。",
  "categories": {}
}
```

`profile` が heads-up のパーソナライズの鍵。具体的に書くほど、より的確な提案が届く。

### 4. カテゴリを追加

まず discovery（発見）カテゴリを追加する。これが heads-up のキラーフィーチャー:

```bash
./add-category.sh discovery "発見" \
  "この人のプロフィールを踏まえて、周辺で今後1ヶ月以内に開催される「この人が普段は自分で調べないが、知れば行ってみたい・やってみたいと思うかもしれない」期間限定の体験・イベント\n- プロフィールの趣味や興味の延長線上にないものを優先\n- 無料または低コストのものを含める\n- 該当するものだけ出力（3-5件程度）" \
  "刈谷ハイウェイオアシス マルシェ（入場無料）"
```

続けて他のカテゴリも追加:

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
  config.json                      # カテゴリ設定 + プロフィール（.gitignore 対象）
  sync.sh                          # メイン同期スクリプト
  add-category.sh                  # カテゴリ追加スクリプト
  com.lifesync.calendar.plist      # launchd 定期実行設定
  sync.log                         # 実行ログ（.gitignore 対象）
```
