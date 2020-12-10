module Mulukhiya
  module Meisskey
    class Account < MongoCollection
      include AccountMethods

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            url: uri.to_s,
            id_admin: admin?,
            id_moderator: moderator?,
          )
          @hash[:display_name] = acct.to_s if @hash[:display_name].empty?
          @hash.delete(:password)
          @hash.deep_compact!
        end
        return @hash
      end

      def acct
        @acct ||= Acct.new("@#{username}@#{host || Environment.domain_name}")
        return @acct
      end

      def uri
        unless @uri
          @uri = Ginseng::URI.parse("https://#{host}") if host
          @uri ||= Environment.sns_class.new.uri.clone
          @uri.path = "/@#{username}"
        end
        return @uri
      end

      def recent_status
        note = MeisskeyService.new.notes(account_id: id)&.first
        return Status[note['id']] if note
        return nil
      end

      def admin?
        return isAdmin
      end

      def moderator?
        return isModerator
      end

      def bot?
        return isBot
      end

      def locked?
        return isLocked
      end

      def featured_tag_bases
        return []
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
          return nil if key[:token].nil?
          entry = collection.find(token: key[:token]).first
          return Account.new(entry['_id']) if entry
          return AccessToken.get(hash: key[:token]).account
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
