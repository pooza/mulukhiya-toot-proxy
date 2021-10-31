module Mulukhiya
  class UserTagHandler < TagHandler
    def removal_tags
      return @sns.account.disabled_tags
    end

    def additional_tags
      return @sns.account.user_tags
    end
  end
end
