module Mulukhiya
  class WebhookContract < Contract
    params do
      required(:digest).value(:string)
    end
  end
end
