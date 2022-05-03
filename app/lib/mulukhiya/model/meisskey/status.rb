module Mulukhiya
  module Meisskey
    class Status < MongoCollection
      include Package
      include StatusMethods
      include SNSMethods

      def service
        unless @service
          if Environment.misskey_type?
            @service = sns_class.new
          else
            @service = MeisskeyService.new
          end
        end
        return @service
      end

      def account
        return Account.new(values['userId'])
      end

      def acct
        return account.acct
      end

      def date
        return createdAt.getlocal
      end

      def local?
        return acct.host == Environment.domain_name
      end

      def visibility
        return values[:visibility]
      end

      alias visibility_name visibility

      def uri
        unless @uri
          @uri = Ginseng::URI.parse(values['uri']) if values['uri'].present?
          @uri ||= service.create_uri("/notes/#{id}")
          @uri = create_status_uri(@uri)
        end
        return @uri
      end

      alias public_uri uri

      def attachments
        return values[:files].map {|row| Attachment[row[:id]]}
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

      def to_h
        return super.merge(attachments: values[:files])
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
          return new(entry[:_id]) if entry
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
