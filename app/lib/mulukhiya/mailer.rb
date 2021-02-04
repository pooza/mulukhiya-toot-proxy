module Mulukhiya
  class Mailer < Ginseng::Mailer
    include Package

    def initialize
      @config = Config.instance
      @mail = ::Mail.new(charset: 'UTF-8')
      @mail['X-Mailer'] = Package.name
      @mail.from = "root@#{Environment.hostname}"
      @mail.to = config['/alert/mail/to']
      @mail.delivery_method(:sendmail)
    end

    def subject=(value)
      @mail.subject = "[#{prefix}] #{value}" if prefix
      @mail.subject ||= value
    end
  end
end
