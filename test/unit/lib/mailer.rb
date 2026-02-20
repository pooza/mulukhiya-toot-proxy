module Mulukhiya
  class MailerTest < TestCase
    def disable?
      return true unless Mailer.config?
      return super
    rescue
      return true
    end

    def setup
      return if disable?
      @mailer = Mailer.new
    end

    test '管理者向けメールアドレスの有無' do
      assert_predicate(Mailer, :config?)
    end
  end
end
