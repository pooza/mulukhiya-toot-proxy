module Mulukhiya
  module Meisskey
    class Status < CollectionModel
      def account
        return Account.new(values['userId'])
      end

      def visible?
        return visibility == 'public'
      end

      def uri
        unless @uri
          @uri = Ginseng::URI.parse(values['uri']) if values['uri'].present?
          @uri ||= Environment.sns_class.new.create_uri("/notes/#{id}")
          @uri = TootURI.parse(@uri)
          @uri = NoteURI.parse(@uri) unless @uri&.valid?
          @uri = nil unless @uri&.valid?
        end
        return @uri
      end

      def attachments
        return query['files']
      end

      def to_h
        unless @hash
          @hash = values.clone
          @hash[:uri] = uri.to_s
          @hash[:attachments] = attachments.map(&:to_h)
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
        template = Template.new('note_clipping.md')
        template[:account] = account.to_h
        template[:status] = NoteParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end

      def self.[](id)
        return Status.new(id)
      end

      def self.get(key)
        if key.key?(:uri)
          uri = NoteURI.parse(key[:uri])
          return nil unless uri.valid?
          return Status.new(uri.id)
        end
        entry = collection.find(key).first
        return Status.new(entry['_id']) if entry
      end

      def self.first(key)
        return get(key)
      end

      private

      def collection_name
        return :notes
      end
    end
  end
end
