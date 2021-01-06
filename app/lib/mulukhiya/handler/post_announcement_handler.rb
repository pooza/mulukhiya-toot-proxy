module Mulukhiya
  class PostAnnouncementHandler < AnnouncementHandler
    def announce(announcement, params = {})
      response = sns.post(
        status_field => create_body(announcement, params),
        'visibility' => visibility,
      )
      result.push(url: response['url'])
      return announcement
    end

    private

    def visibility
      return controller_class.visibility_name('unlisted')
    end
  end
end
