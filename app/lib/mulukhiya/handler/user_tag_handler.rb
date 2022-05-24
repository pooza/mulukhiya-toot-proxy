module Mulukhiya
  class UserTagHandler < TagHandler
    def removal_tags
      return sns.account.disabled_tags
    end

    def addition_tags
      return sns.account.user_tags
    end

    def extra_minutes
      return handler_config(:extra_minutes)
    end
  end
end
