module Mulukhiya
  class MailerTest < TestCase
    def setup
      @mailer = Mailer.new
    end

    test '管理者向けメールアドレスの有無' do
      assert(Mailer.config?)
    end
  end
end
