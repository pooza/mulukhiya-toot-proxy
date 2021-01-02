module Mulukhiya
  class GitHubWebhookContract < Contract
    params do
      required(:digest).value(:string)
    end
  end
end
