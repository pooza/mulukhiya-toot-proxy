module Mulukhiya
  module Meisskey
    class Account < MongoCollection
      include AccountMethods

      def to_h
        return values.deep_symbolize_keys.merge(
          url: uri.to_s,
          is_admin: admin?,
          is_moderator: moderator?,
          is_info_bot: info?,
          is_test_bot: test?,
          display_name: display_name,
        ).except(
          :password,
          :keypair,
        ).deep_compact
      end

      def host
        return values['host'] || Environment.domain_name
      end

      alias domain host

      def uri
        unless @uri
          @uri = Ginseng::URI.parse("https://#{host}") if host
          @uri ||= sns_class.new.uri.clone
          @uri.path = "/@#{username}"
        end
        return @uri
      end

      def display_name
        return name if name.present?
        return acct.to_s
      end

      def fields
        return values['vields'] || []
      end

      def bio
        return description || ''
      end

      def recent_status
        note = service.notes(account_id: id)&.first
        return Status[note['id']] if note
        return nil
      end

      alias recent_post recent_status

      def featured_tags
        tags = TagContainer.new
        return tags unless timelines = values.dig('clientSettings', 'tagTimelines')
        timelines.each do |timeline|
          timeline['query'].each do |entry|
            tags.merge(entry)
          end
        end
        return tags
      rescue => e
        logger.error(error: e, acct: acct.to_s)
        return TagContainer.new
      end

      def admin?
        return isAdmin == true
      end

      def moderator?
        return isModerator == true
      end

      def bot?
        return isBot == true
      end

      def locked?
        return isLocked == true
      end

      def attachments
        unless @attachments
          @attachments = []
          Status.aggregate('account_status', {id: _id}).each do |row|
            @attachments.concat(row[:_files].map {|f| Attachment[f[:_id]]})
          end
        end
        return @attachments
      end

      def self.[](id)
        return Account.new(id)
      end

      def self.get(key)
        return Account.new(key[:id]) if key[:id]
        if acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          entry = collection.find(username: acct.username, host: acct.domain).first
          return Account.new(entry['_id']) if entry
          return nil
        elsif key.key?(:token)
          return nil unless token = (key[:token].decrypt rescue key[:token])
          entry = collection.find(token: token).first
          return Account.new(entry['_id']) if entry
          return AccessToken.get(hash: token).account
        end
        return first(key)
      end

      def self.first(key)
        entry = collection.find(key).first
        return Account.new(entry['_id']) if entry
        return nil
      end

      def self.collection
        return Mongo.instance.db[:users]
      end

      private

      def collection_name
        return :users
      end
    end
  end
end
