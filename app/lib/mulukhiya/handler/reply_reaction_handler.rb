module Mulukhiya
  class ReplyReactionHandler < Handler
    def handle_post_reaction(payload, params = {})
      return unless status = status_class[payload[status_key]]
      return unless receipt = status.account
      return if receipt.reactionable?
      sns.post("#{receipt.acct} #{payload[:reaction]}", {reply: status})
      result.push(reply: status.id, reaction: payload[:reaction])
    end
  end
end
