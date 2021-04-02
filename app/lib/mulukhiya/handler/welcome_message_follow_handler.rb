module Mulukhiya
  class WelcomeMessageFollowHandler < Handler
    def disable?
      return true unless Environment.dbms_class.config?
      return false
    end

    def handle_follow(payload, params = {})
      logger.info(payload)
    end
  end
end
