# Hikaru Goto academic website

Quartoで構築した研究者個人サイトです。公開先はGitHub Pages、独自ドメインは `hikarugoto.com` を想定しています。

## 構成

- `index.qmd`: Home
- `research.qmd`: Research
- `publications.qmd`: Publications
- `materials.qmd`: Materials（教材）
- `contact.qmd`: Contact
- `en/index.qmd`: English profile
- `_quarto.yml`: サイト全体の設定
- `_brand.yml` / `styles.scss`: 配色・組版・レイアウト
- `.github/workflows/publish.yml`: GitHub Pagesへの自動公開
- `AAM/aam-jrcs-2026/`: JRCS論文の著者最終稿、データ、Rスクリプト

## ローカル確認

Quartoをインストールした環境で、次を実行します。

```bash
quarto preview
```

公開用ファイルだけを生成する場合は、次を使います。

```bash
quarto render
```

生成物は `_site/` に出力され、Gitでは管理しません。

## 通常の更新・公開手順

### 1. 修正して確認する

「構成」から対象ファイルを選び、業績・資料・連絡先の変更では「更新時の注意」を確認して編集します。変更内容に応じた確認範囲は [AGENTS.md](AGENTS.md) の「確認と完了」に従います。

- ページを変更したら、「ローカル確認」の `quarto preview` で対象ページを開き、文章・表示・リンク先を確認します。PDFやデータのリンクを追加・変更した場合は、リンクから目的のファイルを開けることも確認します。
- 公開前には `quarto render` でサイト全体を生成し、エラーがないことを確認します。URL関連の変更では、生成したHTMLの `rel="canonical"` と `_site/sitemap.xml` を照合します。
- READMEなど作業用文書だけの変更では、記述・参照先・差分を確認すればよく、サイトの再生成は不要です。

Quartoを使えない環境では、表示・生成の未確認箇所を記録します。公開まで依頼されている場合は、公開処理と公開ページで確認できる範囲を補います。

### 2. 変更を保存し、公開する

まず `git status --short` と `git diff` で変更対象と差分を確認します。今回の変更に必要なファイルだけをステージし、`git diff --cached` で保存対象を再確認してコミットします。新規ファイルの内容はステージ後の差分で確認できます。

**GitHub上の `main` に変更を反映すると、自動公開が始まります。** 公開まで依頼されている場合に、変更を `main` へpushするか、作業ブランチの変更を `main` にマージします。コミットだけでは公開されません。

pushが他の更新との競合で拒否された場合は、リモートの変更を取得して差分を確認し、変更を統合してから再度pushします。強制pushで上書きしません。

### 3. 公開結果を確認する

1. GitHubの [Publish Quarto website](https://github.com/hikarugoto1122/hikarugoto1122.github.io/actions/workflows/publish.yml) を開き、今回反映したコミットに対応する実行を選びます。
2. `build` と `deploy` の両方が成功していることを確認します。失敗した場合は、失敗したステップのログを確認して原因を修正します。
3. [公開サイト](https://hikarugoto.com/) の変更したページを再読み込みし、今回の文章・表示・リンクが反映されたことを確認します。追加・変更した公開ファイルも、公開ページのリンクから開きます。
4. URL関連を変更した場合は、公開ページの正規URLと [公開サイトマップ](https://hikarugoto.com/sitemap.xml) の整合も確認します。

公開までの依頼は、公開処理の成功と実際の反映確認を終えた時点で完了です。公開処理の成功だけでは、内容や表示の確認を終えたことにはしません。

## GitHub Pagesの初期設定

1. このフォルダをGitHubリポジトリへpushする。
2. GitHubの `Settings > Pages > Build and deployment` でSourceを `GitHub Actions` にする。
3. `Settings > Pages > Custom domain` に `hikarugoto.com` を登録する。
4. XServerドメインのDNSで、ホスト名 `@` に次のAレコードを設定する。

```text
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

IPv6を使う場合は、同じく `@` に次のAAAAレコードも設定します。

```text
2606:50c0:8000::153
2606:50c0:8001::153
2606:50c0:8002::153
2606:50c0:8003::153
```

`www.hikarugoto.com` も使う場合は、ホスト名 `www` のCNAMEを `<GitHubユーザー名>.github.io` に向けます。GitHub Pages側でHTTPSを有効にできる状態になったら、`Enforce HTTPS` をオンにします。

## 更新時の注意

- Homeの主要論文は3〜4本に絞り、新しい代表論文が出たら入れ替える。
- 全業績はPublicationsとresearchmapに蓄積する。
- 査読中の論文はPublicationsに追加せず、採択後に `Forthcoming` または `In press` として追加する。
- 問い合わせフォームのURLを変更した場合は、`contact.qmd` と `en/index.qmd` のリンクを更新する。
- `ドメイン情報.txt` はアカウント情報を含むため、Gitの公開対象にしない。
