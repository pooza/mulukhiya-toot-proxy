module Mulukhiya
  class GoodMorningHandler < Handler
    def handle_post_toot(body, params = {})
      @status = body[status_field] || ''
      return body unless executable?(body)
      Program.instance.update
      @result.push(program: {updated: true})
      return body
    end

    private

    def executable?(body)
      return false unless @sns.account.admin? || Environment.test?
      return false if parser.accts.count.positive?
      return @status.match?(config['/handler/good_morning/pattern'])
    end
  end
end
