module Mulukhiya
  # Mastodon 系（Mastodon・Akkoma）のテスト用アカウントの添付の後始末（#4938）。
  #
  # ⚠ Mastodon 系の API には、投稿に付いた添付だけを消す口が無い（`DELETE /api/v1/media/:id` は
  # 投稿に付いていないものだけ）。gem の `MastodonService` に `delete_attachment` が無いので、
  # 共通の `clear_attachments` は 1 件ごとに `NoMethodError` で落ちていた（Mastodon はそもそも
  # `attachments` が無く `ImplementError`）。v4 の Pleroma 版と同じく、添付のある投稿ごと消す。
  # 投稿は API（`only_media`）で引くので、Mastodon と Akkoma で同じ形になる。
  module MediaStatusClearMethods
    # 設定（`/{controller}/status/delete/limit`）が無いときの 1 回ぶん。Mastodon の API の上限に合わせた。
    DEFAULT_LIMIT = 40

    def clear_attachments(params = {})
      raise Ginseng::AuthError, 'Only test users can run it' unless test?
      statuses = service.media_statuses(api_id, limit: status_delete_limit)
      bar = ProgressBar.create(total: statuses.count)
      statuses.each do |status|
        service.delete_status(status['id'])
      rescue => e
        e.log(acct: acct.to_s)
      ensure
        bar&.increment
      end
      bar&.finish
      return statuses.count
    end

    def status_delete_limit
      return controller_class.status_delete_limit || DEFAULT_LIMIT
    end
  end
end
