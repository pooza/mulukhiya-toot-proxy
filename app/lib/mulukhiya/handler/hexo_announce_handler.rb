require 'date'

module Mulukhiya
  class HexoAnnounceHandler < AnnounceHandler
    def disable?
      return true unless category
      return true unless dir
      return super
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
      basename = announcement[:title] || announcement.to_json.adler32
      return File.join(dir, "#{Date.today.strftime('%Y%m%d')}#{basename}.md")
    end

    private

    def category
      return config['/handler/hexo_announce/category'] rescue nil
    end

    def dir
      path = config['/handler/hexo_announce/path']
      path = File.join(Environment.dir, path) unless path.start_with?('/')
      return path
    end
  end
end
