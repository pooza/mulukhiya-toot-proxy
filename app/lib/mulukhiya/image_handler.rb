module Mulukhiya
  class ImageHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      threads = []
      parser.uris.each do |uri|
        thread = Thread.new do
          body[attachment_field] ||= []
          raise 'Too many attachments' if attachment_limit <= body[attachment_field].count
          if image = upload(uri, params)
            body[attachment_field].push(image)
          end
        end
        threads.push(thread)
      end
      threads.each(&:join)
      return body
    end

    def updatable?(uri)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_image_uri(uri)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def verbose?
      return false
    end

    private

    def initialize(params = {})
      super
      @image_uris = {}
    end

    def upload(uri, params)
      return unless updatable?(uri)
      return unless image = create_image_uri(uri)
      id = sns.upload_remote_resource(image, {
        response: :id,
        trim_times: params[:trim_times],
      })
      result.push(source_url: uri.to_s, image_url: image.to_s)
      return id
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
    end
  end
end
