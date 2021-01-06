module Mulukhiya
  class WebhookTestCaseFilter < TestCaseFilter
    def active?
      return true unless controller_class.webhook?
      return account.webhook.nil?
    rescue
      return true
    end
  end
end
