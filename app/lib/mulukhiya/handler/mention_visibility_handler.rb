module Mulukhiya
  class MentionVisibilityHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      parser.accts.select(&:agent?).each do |acct|
        body['visibility'] = controller_class.visibility_name('direct')
        result.push(acct: acct.to_s)
      end
      return body
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, status: @status)
    end
  end
end
