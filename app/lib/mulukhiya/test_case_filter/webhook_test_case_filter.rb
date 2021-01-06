module Mulukhiya
  class WebhookTestCaseFilter < TestCaseFilter
    def active?
      return true unless Environment.controller_class.webhook?
      return account.webhook.nil?
    rescue Ginseng::ConfigError
      return true
    end
  end
end
