# Rack/Sidekiq アップグレード検討記録

**日付**: 2026-01-24

## 背景

Sidekiq 8.1系へのアップグレードを検討したが、rackの依存関係に問題がある。

### 現在の構成

| パッケージ | バージョン | 制約 |
|-----------|-----------|------|
| sidekiq | 8.0.10 | `~> 8.0.5` |
| rack | 3.1.19 | `~> 3.1.14` (ginseng-webで固定) |
| sinatra | 4.1.1 | `~> 4.1.0` |
| puma | 7.2.0 | |

### Sidekiq 8.1の要件

- rack >= 3.2.0 が必須
- 現在のginseng-web (stableブランチ) の制約と競合

## 過去の問題

### 問題発生期間

**2025-10-12 〜 2025-10-26** (約2週間)

- rack >= 3.2.3 + Sinatra >= 4.2.0 の組み合わせで運用
- 2025-10-26 に revert

### 発生した不具合

**異なるアカウントの投稿として送信される**という致命的な問題が発生。

- 複数ユーザーの（ほぼ）同時アクセス時に発生
- 投稿プロキシとして絶対に許容できない不具合

### 原因調査結果

| 調査項目 | 結果 |
|----------|------|
| rack 3.2.x Changelog | スレッドセーフティ関連の修正記載なし |
| Sinatra 4.2.x Changelog | スレッドセーフティ関連の修正記載なし |
| GitHub Issues | 同様の問題報告なし |
| 自分のコード | 設計上はリクエスト間で分離されている |

**結論: 原因の完全な特定は困難**

可能性として考えられるもの：
1. rack 3.2.0-3.2.3の未報告バグ（後に修正された可能性）
2. rack 3.2 + Sinatra 4.2の組み合わせ固有の問題
3. rack 3.2のspec変更（env keysが文字列必須など）への非互換

## 技術的な調査内容

### セッション/リクエスト処理の流れ

```
リクエスト
  → @headers設定 (ginseng-web before)
  → @sns作成 + token設定 (Controller before)
  → sns.toot()
```

### Sinatraのスレッドセーフティ

- Sinatra自体はスレッドセーフ
- リクエストごとに新しいインスタンスを作成
- インスタンス変数はリクエスト間で分離

### Rack Middlewareの注意点

- Rack middlewareは1つのインスタンスが共有される
- インスタンス変数はスレッド間で共有される可能性がある

### Puma設定

- workers: 0 (シングルプロセス)
- threads: 5 (マルチスレッド)

## ginseng-webのブランチ状況

| ブランチ | rack | sinatra | 備考 |
|---------|------|---------|------|
| stable (使用中) | `~> 3.1.14` | `~> 4.1.0` | 安定版、rack 3.1系に固定 |
| main | `>= 3.2.3` | `>= 4.2.0` | Sinatraクラス削除済み |

**注意**: mainブランチでは `Ginseng::Web::Sinatra` クラスが削除されているため、mulukhiya-toot-proxyはstableブランチを使い続ける必要がある。

## 対応方針

### 現時点の決定

**Sidekiq 8.0.x を継続使用**

- 緊急性がない
- 原因が特定できないままアップグレードはリスクが高い

### 検討中の防御策

投稿前の整合性チェック機能の追加：

```ruby
def verify_token_integrity!
  # リクエストヘッダーから再取得
  expected_token = @headers['Authorization']&.split(/\s+/)&.last

  # snsに設定されているトークンと比較
  if sns.token != expected_token
    logger.error(
      event: 'token_mismatch',
      expected: expected_token&.first(8),
      actual: sns.token&.first(8),
      path: request.path,
    )
    raise Ginseng::AuthError, 'Token integrity check failed'
  end
end
```

投稿後の検証：

```ruby
# 投稿結果のアカウントIDを検証
posted_account_id = reporter.response.parsed_response.dig('account', 'id')
if posted_account_id && posted_account_id != sns.account&.id.to_s
  logger.error(
    event: 'account_mismatch_detected',
    expected_account: sns.account&.id,
    posted_as: posted_account_id,
  )
  # アラート送信
end
```

### 効果

| 状況 | 結果 |
|------|------|
| 正常時 | チェック通過、通常動作 |
| 状態汚染発生 | 投稿前に検出・中止 |
| 万が一投稿された場合 | ログに記録、アラート送信 |

## 長期的な検討事項

- rack 3.2系が十分に安定するまで待つ
- 防御コードを実装してからテスト環境で再検証
- エコシステム全体の安定性を継続的に監視

## 参考リンク

- [Puma情報漏洩問題 (GHSA-rmj8-8hhh-gv5h)](https://github.com/puma/puma/security/advisories/GHSA-rmj8-8hhh-gv5h)
- [Sinatraスレッドセーフティ](https://sinatrarb.com/intro.html)
- [Rack Changelog](https://github.com/rack/rack/blob/main/CHANGELOG.md)
- [Sinatra Changelog](https://github.com/sinatra/sinatra/blob/main/CHANGELOG.md)
