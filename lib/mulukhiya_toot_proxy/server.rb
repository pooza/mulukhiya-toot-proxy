module MulukhiyaTootProxy
  class Server < Ginseng::Sinatra
    include Package

    def before_post
      super
      return unless @headers['HTTP_AUTHORIZATION']
      @mastodon = Mastodon.new(
        (@config['/instance_url'] || "https://#{@headers['HTTP_HOST']}"),
        @headers['HTTP_AUTHORIZATION'].split(/\s+/)[1],
      )
    end

    post '/api/v1/statuses' do
      tags = params['status'].scan(tag_pattern).map(&:first)
      results = Handler.exec_all(params, @headers, @mastodon)
      r = @mastodon.toot(params)
      @renderer.message = r.parsed_response
      @renderer.message['results'] = results.join(', ')
      @renderer.message['tags']&.keep_if{|v| tags.include?(v['name'])}
      @renderer.status = r.code
      headers({'X-Mulukhiya' => results.join(', ')})
      return @renderer.to_s
    end

    post '/mulukhiya/webhook/:digest' do
      unless webhook = Webhook.create(params[:digest])
        raise Ginseng::NotFoundError, "Resource #{request.path} not found."
      end
      params[:text] ||= params[:body]
      raise Ginseng::RequestError, 'empty message' unless params[:text].present?
      @renderer.message = webhook.toot(params[:text]).parsed_response
      return @renderer.to_s
    end

    get '/mulukhiya/webhook/:digest' do
      unless Webhook.create(params[:digest])
        raise Ginseng::NotFoundError, "Resource #{request.path} not found."
      end
      @renderer.message = {message: 'OK'}
      return @renderer.to_s
    end

    not_found do
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      e = Ginseng::Error.create(e)
      e.package = Package.full_name
      @renderer.status = e.status
      @renderer.message = e.to_h.delete_if{|k, v| k == :backtrace}
      @renderer.message['error'] = e.message
      Slack.broadcast(e.to_h) unless e.status == 404
      @logger.error(e.to_h)
      return @renderer.to_s
    end

    private

    def tag_pattern
      return Regexp.new(@config['/mastodon/hashtag/pattern'], Regexp::IGNORECASE)
    end
  end
end
