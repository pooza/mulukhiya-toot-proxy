module Mulukhiya
  class ReplyReactionHandler < Handler
    def toggleable?
      return false unless controller_class.reaction?
      return super
    end

    def handle_post_reaction(payload, params = {})
      payload[status_key] ||= payload[:status_id]
      payload[:reaction] ||= payload[:emoji]
      return unless status = status_class[payload[status_key]]
      return unless receipt = status.account
      return if receipt.reactionable?
      sns.post("#{receipt.acct} リアクション:#{payload[:reaction]}", {reply: status.to_h})
      result.push(reply: status.id, reaction: payload[:reaction])
    end
  end
end
