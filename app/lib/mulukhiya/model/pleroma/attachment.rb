module Mulukhiya
  module Pleroma
    class Attachment < Sequel::Model(:objects)
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

      def to_h
        @hash ||= data.deep_compact
        return @hash
      end
    end
  end
end
