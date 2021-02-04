module Mulukhiya
  class Mailer < Ginseng::Mailer
    include Package

    def initialize
      @config = Config.instance
      @config['/mail/to'] = config['/alert/mail/to']
      super
      @prefix = nil
      @mail['X-Mailer'] = Package.full_name
    end

    def subject=(value)
      @mail.subject = "[#{prefix}] #{value}" if prefix
      @mail.subject ||= value
    end
  end
end
