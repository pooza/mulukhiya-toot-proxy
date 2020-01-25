module Mulukhiya
  class MentionVisibilityHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field].to_s
      return if parser.command?
      parser.accts do |acct|
        next unless @config['/agent/accts'].member?(acct)
        body['visibility'] = Environment.controller_class.visibility_name('direct')
        @result.push(acct)
      end
      return body
    end
  end
end
