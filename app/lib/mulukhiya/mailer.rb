module Mulukhiya
  class Mailer < Ginseng::Mailer
    include Package
    include SNSMethods

    def name
      return Package.full_name
    end

    def default_prefix
      return nil
    end

    def default_receipt
      receipt = (config['/alert/mail/to'] rescue nil)
      receipt ||= sns_class.new.maintainer_email
      return receipt
    end

    def self.config?
      return Mailer.new.default_receipt.present?
    end
  end
end
