# CARDINAL.md — このプロジェクトの巡回定義

CardinalSystem（`cardinal-system` スキル）が巡回のたびに読む。プロジェクトのルート、`.cardinal/`、`.claude/` のどれかに置く。

## 1. 見回り項目

上から順に見る。「正常」の条件を満たさなければ異常として扱う。

| # | 項目 | 確認コマンド・見る場所 | 正常 |
|---|---|---|---|
| 1 | テスト | `npm test` | 終了コード0 |
| 2 | 構文 | 直近24時間に変更された `scripts/*.js` に `node --check` | 全部0 |
| 3 | 定期ジョブ | `reports/daily.json` の更新時刻 | 26時間以内 |
| 4 | ログ | `logs/*.log` の直近24時間 | `ERROR` 行なし |

## 2. 直してよい範囲

- `scripts/` 以下のバグ修正（構文・パス・引数・例外処理）
- ドキュメントの誤記

## 3. 触らないもの（共通ルールに追加）

- `config/production.*`
- `data/` 以下（読むだけ）

## 4. 報告先

- `.cardinal/ledger.md`（既定）
