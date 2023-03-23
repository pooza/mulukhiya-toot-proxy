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
      return unless executable?(receipt)
      sns.post({
        status_field => create_status(payload:, receipt:),
        visibility_field => controller_class.visibility_name(:unlisted),
      }, {reply: status.to_h})
      result.push(reply: status.id, reaction: payload[:reaction])
    end

    def create_status(params)
      template = Template.new('reaction.md')
      template[:payload] = params[:payload]
      template[:receipt] = params[:receipt]
      return template.to_s
    end

    private

    def executable?(receipt)
      return false if receipt.reactionable?
      return false unless remote_mulukhiya = receipt.service.nodeinfo[:mulukhiya]
      logger.info(remote_mulukhiya:)
      return false unless version = remote_mulukhiya.dig(:package, :version)
      return if Gem::Version.create(version) < Gem::Version.create('4.27.0')
      return true
    end
  end
end
