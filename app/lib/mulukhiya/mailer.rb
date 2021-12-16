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
      return Handler.create('mail_alert')&.receipt
    end

    def self.config?
      return new.default_receipt.present?
    end
  end
end
