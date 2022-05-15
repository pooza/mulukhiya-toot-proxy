module Mulukhiya
  class MailerTest < TestCase
    def disable?
      return true if Environment.ci?
      return super
    end

    def setup
      @mailer = Mailer.new
    end

    test '管理者向けメールアドレスの有無' do
      assert_predicate(Mailer, :config?)
    end
  end
end
