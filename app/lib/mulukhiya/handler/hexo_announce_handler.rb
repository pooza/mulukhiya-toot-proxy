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
      return handler_config(:category)
    end

    def path
      basename = payload[:title] || payload.to_json.adler32
      return File.join(dir, "#{Date.today.strftime('%Y%m%d')}#{basename}.md")
    end

    def dir
      path = handler_config(:path)
      return File.join(Environment.dir, path) unless path.start_with?('/')
    end
  end
end
