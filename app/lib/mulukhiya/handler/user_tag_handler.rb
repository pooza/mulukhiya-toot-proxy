module Mulukhiya
  class UserTagHandler < TagHandler
    def removal_tags
      return sns.account.disabled_tags
    end

    def schema
      return super.deep_merge(
        type: 'object',
        properties: {
          tags: {
            type: 'object',
            properties: {
              extra_minutes: {type: 'integer'},
            },
          },
        },
      )
    end

    def addition_tags
      return sns.account.user_tags
    end
  end
end
