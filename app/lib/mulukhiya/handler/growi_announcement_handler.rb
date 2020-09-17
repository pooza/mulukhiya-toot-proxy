module Mulukhiya
  class GrowiAnnouncementHandler < Handler
    def handle_announce(announcement, params = {})
      return unless params[:sns]
      return unless growi = params[:sns]&.account&.growi
      @status = announcement[:content] || announcement[:text]
      body = {
        path: GrowiClipper.create_path(params[:sns].account.username),
        body: create_body(announcement),
      }
      growi.clip(body)
      result.push(body)
    end

    def create_body(announcement, params = {})
      params[:body] = parser.to_md
      params.merge!(announcement)
      template = Template.new('announcement')
      template.params = params
      return template.to_s
    end
  end
end
