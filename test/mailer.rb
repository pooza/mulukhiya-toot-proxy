module Mulukhiya
  class MailerTest < TestCase
    def setup
      @mailer = Mailer.new
    end

    def test_default_receipt
      @mailer.default_receipt
    end

    def test_config?
      assert(Mailer.config?)
    end
  end
end
