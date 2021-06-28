module Mulukhiya
  class ImageHandler < Handler
    def handle_pre_toot(body, params = {})
      self.envelope = body
      return body if parser.command?
      threads = []
      parser.uris.each do |uri|
        thread = Thread.new do
          body[attachment_field] ||= []
          raise 'Too many attachments' if attachment_limit <= body[attachment_field].count
          if id = upload(uri, params[:trim_times])
            body[attachment_field].push(id)
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

    def upload(uri, trim_times = 0)
      return unless updatable?(uri)
      return unless image = create_image_uri(uri)
      params = {file: {tempfile: MediaFile.download(image)}}
      Event.new(:pre_upload, {reporter: reporter, sns: sns}).dispatch(params)
      id = sns.upload(params[:file][:tempfile].path, {
        response: :id,
        version: 1,
        filename: File.basename(uri.path),
        trim_times: trim_times,
      })
      Event.new(:post_upload, {reporter: reporter, sns: sns}).dispatch(params)
      result.push(source_url: uri.to_s, image_url: image.to_s)
      return id
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
    end
  end
end
