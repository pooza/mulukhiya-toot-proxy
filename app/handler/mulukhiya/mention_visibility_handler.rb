module Mulukhiya
  class MentionVisibilityHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field].to_s
      return body if parser.command?
      parser.accts do |acct|
        next unless acct.agent?
        body['visibility'] = Environment.controller_class.visibility_name('direct')
        @result.push(acct.to_s)
      end
      return body
    end
  end
end
