module Mulukhiya
  class HexoAnnouncementHandler < Handler
    def handle_announce(announcement, params = {})
      return unless params[:sns]
      @status = announcement[:content] || announcement[:text]
      File.write(create_path(announcement), create_body(announcement))
      result.push(path: create_path(announcement))
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, accouncement: accouncement)
      return false
    end

    def create_path(announcement)
      basename = announcement[:title] || Digest::SHA1.hexdigest(announcement.to_json)
      return File.join(dir, "#{Date.today.strftime('%Y%m%d')}#{basename}.md")
    end

    def dir
      path = @config['/worker/announcement/local_clipping/path']
      path = File.join(Environment.dir, path) unless path.start_with?('/')
      return path
    end

    def create_body(announcement, params = {})
      params[:body] = parser.to_md
      params[:header] = true
      params.merge!(announcement)
      template = Template.new('announcement')
      template.params = params
      return template.to_s
    end
  end
end
