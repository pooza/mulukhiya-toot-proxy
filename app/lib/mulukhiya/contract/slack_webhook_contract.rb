module Mulukhiya
  class SlackWebhookContract < Contract
    params do
      required(:digest).value(:string)
      required(:text).value(:string)
    end
  end
end
