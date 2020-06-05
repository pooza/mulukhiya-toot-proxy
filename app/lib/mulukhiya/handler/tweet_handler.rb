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
      return body unless tweetable?(body)
      uri = create_status_uri(params[:reporter].response)
      TweetWorker.perform_async(
        account_id: sns.account.id,
        status: @status,
        url: uri.to_s,
        spoiler_text: body['spoiler_text'],
      )
      result.push(url: uri.to_s)
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

    def create_status_uri(response)
      uri = @sns.uri.clone
      Slack.broadcast(response.parsed_response)
      if id = response.parsed_response.dig('createdNote', 'id')
        uri.path = "/notes/#{id}"
      else
        uri = Ginseng::URI.parse(response['url'])
      end
      return uri
    rescue=> e
      errors.push(class: e.class.to_s, message: e.message)
      return uri
    end
  end
end
