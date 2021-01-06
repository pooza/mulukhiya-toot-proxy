module Mulukhiya
  module Misskey
    class Status < Sequel::Model(:note)
      include Package
      include StatusMethods
      many_to_one :account, key: :userId

      def local?
        return userHost.nil?
      end

      def uri
        unless @uri
          @uri = Ginseng::URI.parse(self[:uri]) if self[:uri].present?
          @uri ||= sns_class.new.create_uri("/notes/#{id}")
          @uri = TootURI.parse(@uri)
          @uri = NoteURI.parse(@uri) unless @uri&.valid?
          @uri = nil unless @uri&.valid?
        end
        return @uri
      end

      alias public_uri uri

      def attachments
        @attachments ||= fileIds.match(/\{(.*)\}/)[1].split(',').map do |id|
          Attachment[id]
        end
        return @attachments
      rescue => e
        logger.error(error: e)
        return []
      end

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            uri: uri.to_s,
            url: uri.to_s,
            attachments: query['files'],
          )
          @hash.deep_compact!
        end
        return @hash
      end

      def query
        return sns_class.new.fetch_status(id)
      end

      def to_md
        return uri.to_md
      rescue => e
        logger.error(error: e)
        template = Template.new('status_clipping.md')
        template[:account] = account.to_h
        template[:status] = NoteParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end
    end
  end
end
