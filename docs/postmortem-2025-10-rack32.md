# ポストモーテム: rack 3.2 トークン汚染インシデント (2025-10)

**発生期間**: 2025-10-12 〜 2025-10-26（約2週間）
**記録日**: 2026-01-24
**解決日**: 2026-02-15（rack 3.2.5 + 防御策で運用再開）

## 概要

rack 3.2.3 + Sinatra 4.2.0 の組み合わせで運用中、**異なるアカウントの投稿として送信される**という致命的な問題が発生した。投稿プロキシとして絶対に許容できない不具合であり、2025-10-26に rack 3.1系へ revert した。

## 影響

- 複数ユーザーの（ほぼ）同時アクセス時に、他のユーザーのトークンで投稿が送信される
- 投稿プロキシとしての信頼性を根本的に損なうインシデント

## 原因調査

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

## 技術的な背景

### リクエスト処理の流れ

```
リクエスト
  → @headers設定 (ginseng-web before)
  → @sns作成 + token設定 (Controller before)
  → sns.toot()
```

### スレッドモデル

- Sinatra自体はスレッドセーフ（リクエストごとに新インスタンス）
- Rack middlewareは1インスタンスが共有される（インスタンス変数はスレッド間で共有の可能性）
- Puma設定: workers 0（シングルプロセス）、threads 5（マルチスレッド）

## 対応経緯

### Phase 1: 緊急対応（2025-10-26）

rack 3.1系に revert し、Sidekiq 8.0.x を継続使用。

### Phase 2: 防御策の実装（2026-01〜02）

投稿前のトークン整合性チェックを `Controller#verify_token_integrity!` として実装:

```ruby
def verify_token_integrity!
  expected = token
  return unless expected
  return if sns.token == expected
  logger.error(
    event: 'token_mismatch',
    expected: expected.first(8),
    actual: sns.token&.first(8),
    path: request.path,
  )
  raise Ginseng::AuthError, 'Token integrity check failed'
end
```

万が一トークンの状態汚染が再発しても、投稿前に検出・中止する。

### Phase 3: rack 3.2.5 での再検証（2026-02, #4055）

rack 3.2.5 + Sinatra 4.1 + 防御策の組み合わせで同時アクセステストを実施:

- **テスト条件**: 500リクエスト × 2並列
- **結果**: 成功率 100%、トークン不整合 0件
- **結論**: rack 3.2.5 + Sidekiq 8.1 への移行を決定

### 現在の構成（2026-02時点）

| パッケージ | バージョン |
| --------- | --------- |
| rack | 3.2.5 |
| sidekiq | 8.1.x |
| sinatra | 4.1.1 |
| puma | 7.x |

## 教訓

- rack/Sinatraのメジャーバージョンアップは同時アクセステストを必須とする
- 投稿プロキシでは、トークンの整合性チェックを防御策として常時有効にする
- 原因不明のインシデントでも、防御策を先に実装してから段階的にアップグレードすることで安全に前進できる

## 参考リンク

- [Puma情報漏洩問題 (GHSA-rmj8-8hhh-gv5h)](https://github.com/puma/puma/security/advisories/GHSA-rmj8-8hhh-gv5h)
- [Sinatraスレッドセーフティ](https://sinatrarb.com/intro.html)
- [Rack Changelog](https://github.com/rack/rack/blob/main/CHANGELOG.md)
- [Sinatra Changelog](https://github.com/sinatra/sinatra/blob/main/CHANGELOG.md)
