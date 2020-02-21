module Mulukhiya
  module Dolphin
    class Status < Sequel::Model(:note)
      def logger
        @logger ||= Logger.new
        return @logger
      end

      def account
        @account ||= Account[userId]
        return @account
      end

      def local?
        return userHost.nil?
      end

      def visible?
        return visibility == 'public'
      end

      def uri
        unless @uri
          if self[:uri].present?
            @uri = TootURI.parse(self[:uri])
            @uri = NoteURI.parse(self[:uri]) unless @uri&.valid?
            @uri = nil unless @uri&.valid?
          else
            @uri = NoteURI.parse(Config.instance['/dolphin/url'])
            @uri.path = "/notes/#{id}"
          end
        end
        return @uri
      end

      def attachments
        @attachments ||= fileIds.match(/{(.*)}/)[1].split(',').map do |id|
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
          @hash[:uri] ||= uri.to_s
          @hash[:attachments] = attachments.map(&:to_h)
        end
        return @hash
      end

      def to_md
        return uri.to_md
      rescue => e
        logger.error(e)
        template = Template.new('note_clipping.md')
        template[:account] = account.to_h
        template[:status] = NoteParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end
    end
  end
end
