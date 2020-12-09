module Mulukhiya
  module Pleroma
    class Attachment < Sequel::Model(:objects)
      include AttachmentMethos

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
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            type: type,
            subtype: subtype,
            url: uri.to_s,
          )
          @hash.deep_compact!
        end
        return @hash
      end
    end
  end
end
