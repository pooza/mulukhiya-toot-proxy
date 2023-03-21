module Mulukhiya
  class ReplyReactionHandler < Handler
    def disable?
      return true unless controller_class.reaction?
      return super
    end

    def handle_post_reaction(payload, params = {})
      payload[status_key] ||= payload[:status_id]
      payload[:reaction] ||= payload[:emoji]
      return unless status = status_class[payload[status_key]]
      return unless receipt = status.account
      return if receipt.reactionable?
      return unless handlers = receipt.service.nodeinfo.dig(:mulukhiya, :config, :handlers)
      return unless handlers.member?('reply_reaction')
      sns.post({
        status_field => create_status(payload:, receipt:),
        visibility_field => controller_class.visibility_name(:private),
      }, {reply: status.to_h})
      result.push(reply: status.id, reaction: payload[:reaction])
    end

    def create_status(params)
      return [
        params[:receipt].acct,
        "リアクション #{params.dig(:payload, :reaction)} を送りました。",
        '',
        "[#{Package.name}](#{Package.url}) #{Package.version}",
      ].join("\n")
    end
  end
end
