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
      return unless status = status_class[payload[status_key]]
      return unless receipt = status.account
      return if receipt.reactionable? && !Environment.test?
      visibility = bridge_account?(receipt) ? :public : :unlisted
      sns.post({
        status_field => create_status(payload:, receipt:),
        visibility_field => controller_class.visibility_name(visibility),
      }, {reply: status.to_h})
      result.push(reply: status.id, reaction: payload[:reaction])
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
