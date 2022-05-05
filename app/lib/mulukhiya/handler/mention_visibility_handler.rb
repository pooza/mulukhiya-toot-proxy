module Mulukhiya
  class MentionVisibilityHandler < Handler
    def disable?
      return true unless Environment.dbms_class.config?
      return false
    end

    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return if parser.command?
      parser.accts.select(&:agent?).each do |acct|
        payload[visibility_field] = controller_class.visibility_name(:direct)
        result.push(acct: acct.to_s)
      end
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, status: @status)
    end
  end
end
