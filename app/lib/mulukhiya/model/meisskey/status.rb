module Mulukhiya
  module Meisskey
    class Status
      attr_reader :id

      def initialize(id)
        @id = id.to_s
        @logger = Logger.new
      end

      def values
        @values ||= Status.collection.find(_id: BSON::ObjectId.from_string(id)).first.to_h
        return @values
      end

      def account
        return Account.new(values['userId'])
      end

      def visibility
        return values['visibility']
      end

      def local?
      end

      def visible?
        return visibility == 'public'
      end

      def text
        return values['text']
      end

      def uri
        unless @uri
          @uri = NoteURI.parse(Config.instance['/meisskey/url'])
          @uri.path = "/notes/#{id}"
        end
        return @uri
      end

      def attachments
        return []
      end

      def to_h
        unless @hash
          @hash = values.clone
          @hash[:uri] ||= uri.to_s
          @hash[:attachments] = attachments
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

      def self.[](id)
        return Status.new(id)
      end

      def self.first(key)
        return get(key)
      end

      def self.get(key)
        return nil if key[:uri].nil?
        uri = NoteURI.parse(key[:uri])
        return nil unless uri.valid?
        return Status.new(uri.id)
      end

      def self.collection
        return Mongo.instance.db[:notes]
      end
    end
  end
end
