require 'digest/sha1'
require 'date'

module Mulukhiya
  class HexoAnnouncementHandler < AnnouncementHandler
    def disable?
      return super || category.nil? || dir.nil?
    end

    def announce(announcement, params = {})
      params = params.clone
      params[:category] ||= category
      params[:header] = true
      params[:format] = :md
      path = create_path(announcement)
      File.write(path, create_body(announcement, params))
      result.push(path: path)
      return announcement
    end

    def create_path(announcement)
      basename = announcement[:title] || Digest::SHA1.hexdigest(announcement.to_json)
      return File.join(dir, "#{Date.today.strftime('%Y%m%d')}#{basename}.md")
    end

    private

    def category
      return config['/handler/hexo_announcement/category'] rescue nil
    end

    def dir
      path = config['/handler/hexo_announcement/path']
      path = File.join(Environment.dir, path) unless path.start_with?('/')
      return path
    end
  end
end
