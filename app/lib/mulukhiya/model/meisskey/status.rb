module Mulukhiya
  module Meisskey
    class Status < MongoCollection
      include StatusMethods

      def account
        return Account.new(values['userId'])
      end

      def acct
        return account.acct
      end

      def local?
        return acct.host == Environment.domain_name
      end

      def uri
        unless @uri
          @uri = Ginseng::URI.parse(values['uri']) if values['uri'].present?
          @uri ||= sns_class.new.create_uri("/notes/#{id}")
          @uri = Controller.create_status_uri(@uri)
        end
        return @uri
      end

      alias public_uri uri

      def attachments
        return query['files']
      end

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            uri: uri.to_s,
            url: uri.to_s,
            attachments: attachments.map(&:to_h),
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
        template[:account] = account
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
        return nil
      end

      def self.first(key)
        return get(key)
      end

      def self.collection
        return Mongo.instance.db[:notes]
      end

      private

      def collection_name
        return :notes
      end
    end
  end
end
