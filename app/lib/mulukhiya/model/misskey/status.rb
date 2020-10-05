module Mulukhiya
  module Misskey
    class Status < Sequel::Model(:note)
      many_to_one :account, key: :userId

      def logger
        @logger ||= Logger.new
        return @logger
      end

      def local?
        return userHost.nil?
      end

      def visible?
        return visibility == 'public'
      end

      def uri
        unless @uri
          @uri = Ginseng::URI.parse(self[:uri]) if self[:uri].present?
          @uri ||= Environment.sns_class.new.create_uri("/notes/#{id}")
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
        logger.error(e)
        return []
      end

      def to_h
        unless @hash
          @hash = values.clone
          @hash[:uri] = uri.to_s
          @hash[:attachments] = query['files']
          @hash.compact!
        end
        return @hash
      end

      def query
        return Environment.sns_class.new.fetch_status(id)
      end

      def to_md
        return uri.to_md
      rescue => e
        logger.error(e)
        template = Template.new('status_clipping.md')
        template[:account] = account.to_h
        template[:status] = NoteParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end
    end
  end
end
