module Mulukhiya
  module Pleroma
    class Attachment < Sequel::Model(:objects)
      alias to_h data

      def type
        return data['url'].first['mediaType']
      end

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
