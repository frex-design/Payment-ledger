# 引き継ぎ書：外注加工費管理システム（HANDOFF）

作成日: 2026-09-25 ／ 作成: タチコマ（CEO依頼で共有DB配線を実装）

このドキュメントは、**開発を引き継ぐ社員**向けの技術メモです。
「受信箱に用意されたシンプル版フロント（localStorageのみ）」に、**Supabaseの共有バックエンドを接続して本番稼働**させた状態を引き継ぎます。

---

## 0. まず結論（最重要）

> ⚠️ **開発の続きは、この `index.html`（Supabase接続済み）から始めてください。**
> 手元のlocalStorage版（受信箱の元HTML）に戻して作業すると、下記のSupabase接続がまるごと消えます。
> **この版が最新・唯一の作業ベース**です。

- 本番URL: **https://frex-design.github.io/Payment-ledger/**（社員はこれを開くだけ／接続設定入力は不要）
- 構成: 単一 `index.html`（HTML/CSS/JSインライン・ビルド不要）＋ Supabase（PostgreSQL）
- データは全社員で共有（同じテーブルを読み書き）。現在は**空スタート**。

---

## 1. アクセス（追加設定は不要）

- **GitHub・Supabase とも、あなたがログイン済みの同一アカウントで操作できます。** コラボレーター追加やプロジェクト招待は不要。
- GitHubリポジトリ: `frex-design/Payment-ledger`（public）。**push権限は `frex-design` アカウント**（`frex-design-infra` では読めるが書けない）。

---

## 2. Supabase（バックエンド）

| 項目 | 値 |
|---|---|
| プロジェクト参照ID | `twolywmokxggjnugzuig`（"frex-design-infra's Project"・複数アプリ共用） |
| URL | `https://twolywmokxggjnugzuig.supabase.co` |
| テーブル | `public.gaichu_kakouhi`（フラット単一テーブル） |
| anon public キー | `index.html` 内に直接埋め込み（`SUPABASE_ANON_KEY`）。anonキーはSupabase設計上クライアント公開前提のキー |
| アクセス制御 | 認証UIなし。テーブルのRLSポリシーで制御 |

### テーブル定義（`schema.sql` と同一）
```sql
create table if not exists public.gaichu_kakouhi (
  id         uuid        primary key default gen_random_uuid(),
  pay_month  text        not null,   -- 支払い月 'YYYY-MM'
  vendor     text        not null,   -- 外注会社名
  job_name   text        not null,   -- 業務名
  amount     bigint      not null default 0,  -- 金額（円・税込）
  note       text,                   -- 備考
  created_at timestamptz not null default now()
);
create index if not exists idx_gaichu_month  on public.gaichu_kakouhi(pay_month);
create index if not exists idx_gaichu_vendor on public.gaichu_kakouhi(vendor);

alter table public.gaichu_kakouhi enable row level security;
drop policy if exists "anon all gaichu_kakouhi" on public.gaichu_kakouhi;
create policy "anon all gaichu_kakouhi" on public.gaichu_kakouhi
  for all to anon using (true) with check (true);
grant usage on schema public to anon;
grant all on public.gaichu_kakouhi to anon;
notify pgrst, 'reload schema';
```

- **正規化なし・JOINなし**：会社名/業務名は各行にテキスト保持。入力時に過去入力を `<datalist>` で候補補完。
- 集計（月別/会社別/業務別）はフロント側で `groupBy` して表示。
- 旧版（別プロジェクトの vendors/tasks/payments 正規化モデル）とは無関係。旧SQLは `_old_normalized_model/` に退避済み。

### SQLの流し方（テーブル追加・変更など）
Supabase CLI（ログイン済み前提）で、管理API経由で実行できます（DBパスワード不要）:
```bash
mkdir -p /tmp/sblink
supabase link --project-ref twolywmokxggjnugzuig --workdir /tmp/sblink --yes
# 1行SQL
supabase db query --linked --workdir /tmp/sblink -o json "select * from gaichu_kakouhi limit 5;"
# ファイル実行
supabase db query --linked --workdir /tmp/sblink -f schema.sql
```
Supabaseダッシュボードの SQL Editor に貼り付けて実行してもOK。

---

## 3. GitHub & デプロイ

- リポジトリ: `frex-design/Payment-ledger` → **GitHub Pagesが自動ビルド** → 本番URLへ反映（1〜2分）。
- **ローカルの `git` はXcodeライセンス未同意でブロック中**（`git`実行時に license エラー）。そのため `git clone/commit/push` が使えない。
  - **暫定**: `gh api`（Contents API）で直接コミットする（下記）。
  - **恒久解決（推奨）**: `sudo xcodebuild -license` に同意すれば、以後は通常の `git` が使える。
- 反映後は **本番URLを実際に開いて目視確認**してから「反映完了」とすること（キャッシュに注意。`?cb=時刻` を付けて確認すると確実）。

### gh api で index.html を更新する例
```bash
cd "FD products/Payment-ledger"          # 正フォルダ（ローカル実体）
gh auth switch --user frex-design        # push権限のあるアカウントへ
REPO=frex-design/Payment-ledger
SHA=$(gh api repos/$REPO/contents/index.html --jq .sha)
B64=$(base64 < index.html | tr -d '\n')
gh api -X PUT repos/$REPO/contents/index.html \
  -f message="変更内容の説明" -f content="$B64" -f sha="$SHA" --jq '.commit.html_url'
```

---

## 4. 今回タチコマがやった変更点（localStorage版 → Supabase版）

1. `<head>` に Supabase JS SDK v2（CDN）を追加。
2. `Store`（データ窓口）を **localStorage実装 → Supabase実装に差し替え**。メソッド（`list/add/update/remove/replaceAll`）のインターフェースは同一なので、画面側コードは変更不要。
3. `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `TABLE` を先頭に定義しハードコード。
4. **DBエラーの可視化**を追加：トースト通知（成功/エラー）＋接続失敗時の赤バナー（旧版は読み取りエラーを握り潰していた）。
5. テーマ切替の設定のみ localStorage 継続（UI設定なのでDB不要）。

※ CSV出力・バックアップ(JSON)・復元 の機能はそのまま動作（データ源が Supabase になっただけ）。

---

## 5. 保全情報（元の版）

- リポジトリの**元・March版（正規化モデル）は git 履歴の commit `7013844` に完全保存**。必要なら復元可能。
- 現行版のコミット: `62f6685`（index.html刷新）／`6f8eeaf`（README刷新）。

---

## 6. 残タスク・検討候補（任意）

- [ ] **認証の要否**：現状ログインなし＝URL＋キーを知れば誰でも読み書き可（社内ツール前提）。社外流出が心配なら簡易ログイン等を検討。
- [ ] 「支払済/未払い」トグルの要否（旧版にはあった。今回のシンプル版には無い）。
- [ ] 未入力/重複入力のバリデーション強化。
- [ ] （運用が固まったら）RLSポリシーの見直し。

---

## 7. 関連

- ローカル正フォルダ: `FD products/Payment-ledger/`（`index.html` / `schema.sql` / `HANDOFF.md` / 旧SQLは `_old_normalized_model/`）
- 概要ノート: `FD products/外注加工費 支払管理台帳システム.md`
