module MulukhiyaTootProxy
  class ImageResizeHandler < Handler
    def handle_pre_upload(body, params = {})
      Slack.broadcast(body)
    end
  end
end
