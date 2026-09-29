# CardinalSystem

プロジェクトを定期的に見回り、バグ・グリッチを見つけて、**安全に直せるものだけ**自動で直し、検証して記録する
Claude Code 用のスキル。

An autonomous patrol-and-repair skill for Claude Code: it periodically inspects a project (syntax, tests, scheduled jobs,
stale outputs, error logs), fixes only what passes a strict safety gate, verifies the fix, and keeps a ledger.

## 何をするか

```
観測 → 検出 → 仕分け（S1/S2/S3） → 修復（最大3件） → 検証 → 記録（.cardinal/ledger.md）
```

- 直すのは「原因を特定できた・変更が小さい・検証できる・元に戻せる・禁止領域でない」をすべて満たすものだけ
- テストを消す・エラーを握りつぶすような「直ったことにする」修正はしない
- 認証情報・本番データ・課金・外部への公開や送信には触らない
- 直せないものは「要判断」として、人が何を決めればよいかを残す

## 入れ方

```bash
# Claude Code のスキルフォルダに置く
git clone https://github.com/artemislog/cardinal-system.git ~/.claude/skills/cardinal-system
```

## 使い方

| 指示 | すること |
|---|---|
| 「見回って」「巡回して」 | 全項目を巡回し、直せるものは直す |
| 「<対象>がおかしいから見て」 | その対象だけを深く調べて直す |
| 「レポートだけ」 | 直さずに検出と仕分けだけ |

プロジェクト固有の見回り項目は `CARDINAL.md` に書く（`templates/CARDINAL.md` を参照）。無くても自動検出で巡回する。

## 定期巡回

- セッション中: `/loop 6h /cardinal-system`
- クラウド: `/schedule` で毎日 `/cardinal-system`
- 自分のPC: `scripts/patrol.ps1`（Windows タスクスケジューラ）／ `scripts/patrol.sh`（cron）。許可するツールを絞って `claude -p` で1回巡回する

### 無人巡回の注意

- 許可するツールは最小限にしてある（読む・編集・git の参照・構文チェック・テスト）。定期タスクの状態や更新時刻を見るコマンドなど、
  プロジェクト固有の確認が要るときは `-AllowTools`（patrol.ps1）／ `CARDINAL_ALLOW`（patrol.sh）で足す
- `npm test` などはプロジェクトのコードを実行する。信頼できるリポジトリにだけ使う
- 時間切れで打ち切ったとき、環境によっては `claude` の子プロセスが残ることがある。タスクマネージャー／`ps` で確認する

## 名前について

とあるVRMMOの世界で、バグや不具合を自動で見つけて修正し続けるシステムから名前を借りている。非公式の命名で、原作および権利者とは関係ない。
