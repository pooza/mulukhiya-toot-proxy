module Mulukhiya
  class TweetHandler < Handler
    def disable?
      return super || sns.account.twitter.nil?
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      return body unless tweetable?(body)
      TweetWorker.perform_async(account_id: sns.account.id, status: @status)
      result.push(queued: true)
      return body
    end

    private

    def tweetable?(body)
      return false unless parser.accts.count.zero?
      return true unless body['visibility']
      return true if body['visibility'] == 'public'
      return false
    end
  end
end
