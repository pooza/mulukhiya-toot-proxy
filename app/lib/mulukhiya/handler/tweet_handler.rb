module Mulukhiya
  class TweetHandler < Handler
    def disable?
      return super || sns.account.twitter.nil?
    end

    def handle_pre_toot(body, params = {})
      reporter.temp[:tweet] = body[status_field]
      result.push(message: 'saved')
      return body
    end

    def handle_post_toot(body, params = {})
      @status = reporter.temp[:tweet] || body[status_field] || ''
      url = params[:reporter].response['url'] if params[:reporter].response
      return body unless tweetable?(body)
      TweetWorker.perform_async(
        account_id: sns.account.id,
        status: @status,
        url: url,
        spoiler_text: body['spoiler_text'],
      )
      result.push(url: url)
      return body
    end

    private

    def tweetable?(body)
      return false if parser.command?
      return false unless parser.accts.count.zero?
      return true unless body['visibility']
      return true if body['visibility'] == 'public'
      return false
    end
  end
end
