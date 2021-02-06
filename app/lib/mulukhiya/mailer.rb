module Mulukhiya
  class Mailer < Ginseng::Mailer
    include Package

    def name
      return Package.full_name
    end

    def default_prefix
      return nil
    end

    def default_receipt
      return config['/alert/mail/to'] rescue nil
    end
  end
end
