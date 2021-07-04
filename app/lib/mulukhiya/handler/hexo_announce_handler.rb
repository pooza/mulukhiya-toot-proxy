module Mulukhiya
  class HexoAnnounceHandler < AnnounceHandler
    def disable?
      return true unless category
      return true unless dir
      return super
    end

    def announce(params = {})
      params[:category] ||= category
      params[:header] = true
      params[:format] = :md
      File.write(path, create_body(params))
      result.push(path: path)
    end

    private

    def category
      return config['/handler/hexo_announce/category'] rescue nil
    end

    def path
      basename = payload[:title] || payload.to_json.adler32
      return File.join(dir, "#{Date.today.strftime('%Y%m%d')}#{basename}.md")
    end

    def dir
      path = config['/handler/hexo_announce/path']
      path = File.join(Environment.dir, path) unless path.start_with?('/')
      return path
    end
  end
end
