require 'digest/sha1'
require 'date'

module Mulukhiya
  class HexoAnnouncementHandler < AnnouncementHandler
    def announce(announcement, params = {})
      params = params.clone
      params[:category] ||= @config['/worker/announcement/local_clipping/category']
      params[:header] = true
      params[:format] = :md
      path = create_path(announcement)
      File.write(path, create_body(announcement, params))
      result.push(path: path)
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
  end
end
