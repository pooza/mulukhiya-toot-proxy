module Mulukhiya
  module Pleroma
    class Attachment < Sequel::Model(:objects)
      alias to_h data

      def file_content_type
        return data['url'].first['mediaType']
      end

      alias type file_content_type

      def uri
        @uri ||= Ginseng::URI.parse(data['url'].first['href'])
        return @uri
      end

      def data
        @data ||= JSON.parse(values[:data])
        return @data
      end
    end
  end
end
