module Mulukhiya
  module Misskey
    class Account < Sequel::Model(:user)
      include Package
      include AccountMethods
      include SNSMethods
      one_to_one :account_profile, key: :userId
      one_to_many :attachment, key: :userId

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            url: uri.to_s,
            is_admin: admin?,
            is_moderator: moderator?,
            display_name: display_name,
          )
          @hash.delete(:token)
          @hash.deep_compact!
        end
        return @hash
      end

      def display_name
        return name if name.present?
        return acct.to_s
      end

      def host
        return values[:host] || Environment.domain_name
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

      def fields
        return JSON.parse(values[:fields])
      rescue => e
        logger.error(error: e, acct: acct.to_s)
        return []
      end

      def bio
        return account_profile.description || ''
      end

      def recent_status
        notes = service.notes(account_id: id)
        note = notes&.first
        return Status[note['id']] if note
        return nil
      end

      alias recent_note recent_status

      def featured_tag_bases
        tag_bases = []
        service.antennas.map {|v| v['keywords'].first}.each do |keywords|
          tag_bases.concat(keywords.map(&:to_hashtag_base))
        end
        return tag_bases.uniq
      rescue => e
        logger.error(error: e, acct: acct.to_s)
        return []
      end

      alias attachments attachment

      def clear_attachments
        bar = ProgressBar.create(total: attachments.count) if Environment.rake?
        attachments.each do |attachment|
          service.delete_attachment(attachment)
        ensure
          bar&.increment
        end
        bar&.finish
        logger.info(class: self.class.to_s, acct: acct.to_s, message: 'clear')
      end

      alias admin? isAdmin

      alias moderator? isModerator

      alias service? isBot

      alias bot? isBot

      alias locked? isLocked

      def self.get(key)
        if acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return first(username: acct.username, host: acct.domain)
        elsif key.key?(:token)
          return nil if key[:token].nil?
          return first(key) || AccessToken.first(hash: key[:token]).account
        end
        return first(key)
      end
    end
  end
end
