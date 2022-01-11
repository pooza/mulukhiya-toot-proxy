module Mulukhiya
  class WebhookTestCaseFilter < TestCaseFilter
    def active?
      return true unless controller_class.webhook?
      return true unless account.webhook
      return false
    rescue
      return true
    end
  end
end
