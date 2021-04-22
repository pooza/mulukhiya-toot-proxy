module Mulukhiya
  module AccessTokenMethods
    include SNSMethods

    def webhook_digest
      return Webhook.create_digest(sns_class.new.uri, to_s)
    end
  end
end
