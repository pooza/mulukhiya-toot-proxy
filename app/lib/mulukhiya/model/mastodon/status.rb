module Mulukhiya
  module Mastodon
    class Status < Sequel::Model(:statuses)
      include Package
      include StatusMethods
      include SNSMethods
      one_to_many :attachment
      many_to_one :account

      def acct
        return account.acct
      end

      alias local? local

      def public?
        return visibility.zero?
      end

      def updatable_by?(target)
        target = Account[target] unless target.is_a?(Account)
        return account&.id == target&.id
      end

      alias attachments attachment

      def uri
        @uri ||= create_status_uri(self[:url] || self[:uri])
        return @uri
      end

      def public_uri
        @public_uri ||= service.create_uri("/@#{account.username}/#{id}")
        return @public_uri
      end

      def webui_uri
        @webui_uri ||= service.create_uri("/mulukhiya/app/status/#{id}")
        return @webui_uri
      end

      def service
        unless @service
          if Environment.mastodon_type?
            @service = sns_class.new
          else
            @service = MastodonService.new
          end
        end
        return @service
      end

      def visibility_name
        return self.class.visibility_names[visibility]
      end

      def date
        return Time.parse(created_at.strftime('%Y/%m/%d %H:%M:%S GMT')).getlocal
      end

      def to_h
        @hash ||= values.deep_symbolize_keys.merge(
          id: id.to_s,
          created_at: date,
          created_at_str: date&.strftime('%Y/%m/%d %H:%M:%S'),
          body:,
          footer:,
          is_taggable: taggable?,
          footer_tags: footer_tags.map(&:to_h),
          webui_url: webui_uri.to_s,
          visibility_name:,
          visibility_icon:,
        ).compact
        return @hash
      end

      def to_md
        return uri.to_md
      rescue => e
        e.log
        template = Template.new('status_clipping.md')
        template[:account] = account.to_h
        template[:status] = TootParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end

      def self.visibility_names
        return [:public, :unlisted, :private, :direct].map {|v| TootParser.visibility_name(v)}
      end
    end
  end
end
