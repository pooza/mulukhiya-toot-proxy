module Mulukhiya
  class PostAnnouncementHandler < AnnouncementHandler
    def announce(announcement, params = {})
      r = sns.post(
        status_field => create_body(announcement, params),
        'visibility' => visibility,
      )
      result.push(url: r['url'])
      return announcement
    end

    private

    def visibility
      return Environment.controller_class.visibility_name('unlisted')
    end
  end
end
