module Mulukhiya
  class ReplyReactionHandler < Handler
    def disable?
      return true unless controller_class.reaction?
      return super
    end

    def handle_post_reaction(payload, params = {})
      payload[status_key] ||= payload[:status_id]
      payload[:reaction] ||= payload[:emoji]
      return unless payload[:reaction].present?
      return unless status = target_status(payload)
      return unless receipt = status.account
      return if receipt.reactionable? && !Environment.test?
      sns.post(create_body(payload, status, receipt), {reply: status.to_h})
      result.push(reply: status.id, reaction: payload[:reaction])
    end

    def create_body(payload, status, receipt)
      visibility = reply_visibility(status, receipt)
      body = {
        status_field => create_status(payload:, receipt:),
        visibility_field => controller_class.visibility_name(visibility),
      }
      body[:visibleUserIds] = [receipt.id] if visibility == :direct && Environment.misskey_type?
      return body
    end

    # ⚠ 元の投稿が公開・未収載でなければ、返信は相手だけに送る（5.46.0 のリリース前レビュー）。
    # 未収載で返すと、非公開の投稿があることと、リアクションした人が誰かが見えてしまう。
    # Mastodon・Pleroma 系は本文の先頭の acct で相手に届く。Misskey の `specified` は宛先の ID が要る。
    def reply_visibility(status, receipt)
      return :direct unless open_visibility?(status)
      return bridge_account?(receipt) ? :public : :unlisted
    end

    def open_visibility?(status)
      name = status.visibility_name.to_s
      return [:public, :unlisted].any? {|v| controller_class.visibility_name(v) == name}
    end

    # ⚠ API で読む投稿（`Pleroma::Status`）は、リアクションした本人のサービスで読む（PR #4891 の Codex P2）。
    # 既定のサービスは設定のトークンなので、フォロワー限定・DM の投稿が読めず、返信を投稿できない。
    # DB から読む投稿（Mastodon・Misskey）は `service=` を持たないので何もしない。
    def target_status(payload)
      return nil unless status = status_class[payload[status_key]]
      status.service = sns if status.respond_to?(:service=)
      return status
    end

    def create_status(params)
      template = Template.new('reaction.md')
      if params[:payload][:reaction].start_with?(':')
        params[:payload][:reaction] = params[:payload][:reaction].gsub('@.', '')
      end
      template[:payload] = params[:payload]
      template[:receipt] = params[:receipt]
      return template.to_s
    end

    def bridge_account?(account)
      return bridge_domains.member?(account.domain)
    end

    def bridge_domains
      return handler_config(:bridge_domains) || []
    end
  end
end
