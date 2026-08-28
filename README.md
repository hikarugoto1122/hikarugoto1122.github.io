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
