module Mulukhiya
  class MailAlertHandler < AlertHandler
    def disable?
      return true unless Mailer.config?
      return super
    end

    def alert(params = {})
      mailer = Mailer.new
      mailer.prefix = sns.node_name
      mailer.subject = "#{error.source_class} #{error.message}"
      mailer.body = error.backtrace
      mailer.deliver
    end
  end
end
