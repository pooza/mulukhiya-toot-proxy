module Mulukhiya
  module AccessTokenMethods
    def webhook_digest
      return Webhook.create_digest(Environment.sns_class.new.uri, to_s)
    end
  end
end
