module Mulukhiya
  class UserTagHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      tags.merge(user_tags)
      result.push(tags: user_tags)

      tags.reject! {|v| @sns.account.disabled_tags.member?(v)}
    end

    private

    def default_tags
      return @sns.account.user_tags
    end
  end
end
