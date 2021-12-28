module Mulukhiya
  module Meisskey
    class Status < MongoCollection
      include Package
      include StatusMethods
      include SNSMethods

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
          @uri = create_status_uri(@uri)
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
        e.log
        template = Template.new('status_clipping.md')
        template[:account] = account
        template[:status] = NoteParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end

      def self.[](id)
        return new(id)
      end

      def self.get(key)
        case key
        in {uri: uri}
          uri = NoteURI.parse(uri)
          return nil unless uri.valid?
          return new(uri.id)
        else
          entry = collection.find(key).first
          return new(entry['_id']) if entry
          return nil
        end
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
