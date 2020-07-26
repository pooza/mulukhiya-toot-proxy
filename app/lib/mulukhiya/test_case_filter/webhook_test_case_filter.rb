module Mulukhiya
  class WebhookTestCaseFilter < TestCaseFilter
    def active?
      return true unless Environment.controller_class.webhook?
      return Environment.test_account.webhook.nil?
    rescue Ginseng::ConfigError
      return true
    end
  end
end
