module Mulukhiya
  class BookmarkHandler < Handler
    def handle_post_bookmark(body, params = {})
      return unless uri = Environment.status_class[body[status_key]].uri
      return unless uri.absolute?
      worker_class.perform_async(uri: uri.to_s, account_id: sns.account.id)
      @result.push(url: uri.to_s)
    end

    def worker_class
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def verbose?
      return false
    end
  end
end
