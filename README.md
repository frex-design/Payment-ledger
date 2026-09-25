# 外注加工費管理システム

株式会社フレックスデザインの社内向け「外注加工費（協力会社への支払い）」記録・集計台帳。
全社員が同じデータを共有できる Web アプリ。

- 公開URL: https://frex-design.github.io/Payment-ledger/
- 構成: 単一 `index.html`（HTML/CSS/JS・ビルド不要）＋ Supabase（PostgreSQL）
- テーブル: `public.gaichu_kakouhi`（pay_month / vendor / job_name / amount / note）
- 認証: なし（anon public キー直アクセス・RLSで制御）
