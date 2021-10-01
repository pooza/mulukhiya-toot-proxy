module Mulukhiya
  class PostAnnounceHandler < AnnounceHandler
    def announce(params = {})
      response = sns.post(
        status_field => create_body(params),
        visibility_field => controller_class.visibility_name(:unlisted),
      )
      result.push(url: response['url'])
    end
  end
end
