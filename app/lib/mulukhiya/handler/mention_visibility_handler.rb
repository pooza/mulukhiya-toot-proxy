module Mulukhiya
  class MentionVisibilityHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return payload if parser.command?
      parser.accts.select(&:agent?).each do |acct|
        payload['visibility'] = controller_class.visibility_name('direct')
        result.push(acct: acct.to_s)
      end
      return payload
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, status: @status)
    end
  end
end
