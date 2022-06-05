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
      result.push(path:)
    end

    def category
      return handler_config(:category)
    end

    def dir
      return nil unless dir = handler_config(:dir)
      return File.join(Environment.dir, dir) unless dir&.start_with?('/')
      return dir
    end

    private

    def path
      basename = payload[:title] || payload.to_json.adler32
      return File.join(dir, "#{Date.today.strftime('%Y%m%d')}#{basename}.md")
    end
  end
end
