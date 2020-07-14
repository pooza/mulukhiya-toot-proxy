module Mulukhiya
  module Meisskey
    class Attachment < CollectionModel
      def type
        return contentType
      end

      def uri
        @uri ||= Ginseng::URI.parse(values['src'] || values['uri'])
        return @uri
      end

      def self.[](id)
        return Attachment.new(id)
      end

      private

      def collection_name
        return 'driveFiles.files'
      end
    end
  end
end
