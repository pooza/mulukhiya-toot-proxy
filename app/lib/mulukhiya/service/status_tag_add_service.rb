module Mulukhiya
  class StatusTagAddService
    include Package

    def initialize(sns)
      @sns = sns
    end

    def call(status, tags)
      status.parser.footer_tags.clear
      status.parser.footer_tags.concat(tags)
      body = [
        status.parser.body,
        '',
        status.parser.footer_tags.map(&:to_hashtag).join(' '),
      ].join("\n")
      return @sns.repost(status, body)
    end
  end
end
