module Mulukhiya
  # Pleroma 系（Akkoma）の listener（段階 6・#4901）。v4 の `PleromaListener`（46c4f4e2^）を戻した。
  # ストリーミングは Mastodon 互換なので、イベントの読み方は `MastodonListener` のまま。
  # ⚠ トークンはヘッダではなくクエリで渡る（Akkoma はヘッダを読まない・gem の `PleromaService`）。
  class PleromaListener < MastodonListener
    # ⚠⚠ **API の ID は `users.id`（uuid）ではなく FlakeId**。そのまま `[]` に渡すと引けない。
    # v4 は `fqn` で引いていたが、ID のほうが名前の変更や表記の揺れに左右されない。
    def self.sender(payload)
      return nil unless id = payload.dig('account', 'id')
      return Environment.account_class[FlakeId.decode(id)]
    rescue => e
      e.log
      return nil
    end
  end
end
