module Mulukhiya
  class BookmarkHandler < Handler
    def handle_post_bookmark(payload, params = {})
      return unless uri = status_class[payload[status_key]].uri
      return unless uri.absolute?
      worker_class.perform_async(uri: uri.to_s, account_id: sns.account.id)
      result.push(url: uri.to_s)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
    end

    def worker_class
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def verbose?
      return false
    end
  end
end
