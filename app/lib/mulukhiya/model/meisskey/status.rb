module Mulukhiya
  module Meisskey
    class Status < CollectionModel
      def account
        return Account.new(values['userId'])
      end

      def acct
        return account.acct
      end

      def local?
        return acct.host == Environment.domain_name
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
        @logger.error(e)
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

      def self.tag_feed(params)
        return [] unless Mongo.config?
        user_ids = (params[:test_usernames] || []).map do |id|
          BSON::ObjectId.from_string(Account.get(username: id).id)
        end
        notes = collection
          .find(tags: params[:tag].sub(/^#/, '').downcase, userId: {'$nin' => user_ids})
          .sort(createdAt: -1)
          .limit(params[:limit])
        return notes.map do |row|
          status = Status.new(row['_id'])
          {
            username: status.account.username,
            domain: status.account.acct.host,
            spoiler_text: status.cw,
            text: status.text,
            uri: status.uri.to_s,
            created_at: status.createdAt,
          }
        end
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
