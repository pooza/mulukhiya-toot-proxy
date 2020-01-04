module MulukhiyaTootProxy
  class WebhookTestCaseFilter < TestCaseFilter
    def active?
      return true unless Environment.controller_class.webhook?
      return true unless Environment.test_account.webhook.present?
      return false
    end
  end
end
