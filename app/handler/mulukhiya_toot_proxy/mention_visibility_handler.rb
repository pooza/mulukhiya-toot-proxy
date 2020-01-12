module MulukhiyaTootProxy
  class MentionVisibilityHandler < Handler
    def handle_pre_toot(body, params = {})
      Environment.parser_class.new(body[status_field]).accts.each do |acct|
        next unless @config['/agent/accts'].member?(acct)
        body['visibility'] = Environment.controller_class.visibility_name('direct')
        @result.push(acct)
      end
      return body
    end
  end
end
