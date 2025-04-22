module Mulukhiya
  module ControllerMethods
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def name
        return to_s.split('::').last.sub(/Controller$/, '').underscore
      end

      def display_name
        return config["/#{name}/display_name"] rescue name
      end

      def webhook?
        return config["/#{name}/features/webhook"] == true rescue false
      end

      def media_catalog?
        return config["/#{name}/features/media_catalog"] == true rescue false
      end

      def favorite_tags?
        return config["/#{name}/features/favorite_tags"] == true rescue false
      end

      def feed?
        return config["/#{name}/features/feed"] rescue false
      end

      def oauth_callback?
        return config["/#{name}/oauth/callback/enable"] == true rescue false
      end

      def lemmy?
        return Handler.search(/lemmy/).present?
      end

      def poipiku?
        return Handler.search(/poipiku/).present?
      end

      def max_length
        return parser_class.new.max_length
      end

      def announcement?
        return config["/#{name}/features/announcement"] == true rescue false
      end

      def filter?
        return config["/#{name}/features/filter"] == true rescue false
      end

      def streaming?
        return config["/#{name}/features/streaming"] == true rescue false
      end

      def account_timeline?
        return config["/#{name}/features/account_timeline"] == true rescue false
      end

      def repost?
        return config["/#{name}/features/repost"] == true rescue false
      end

      def reaction?
        return config["/#{name}/features/reaction"] == true rescue false
      end

      def futured_tag?
        return config["/#{name}/features/futured_tag"] == true rescue false
      end

      def annict?
        return false unless config["/#{name.underscore}/features/annict"] == true
        return false unless AnnictService.config?
        return true
      rescue Ginseng::ConfigError
        return false
      end

      def livecure?
        return false unless config['/program/urls'].count.positive?
        return true
      rescue Ginseng::ConfigError
        return false
      end

      def dbms_name
        return config["/#{name}/dbms"]
      end

      def dbms_class
        return "Mulukhiya::#{dbms_name.camelize}".constantize
      rescue NameError
        return nil
      end

      def parser_name
        return config["/#{name}/status/parser"]
      end

      def parser_class
        return "Mulukhiya::#{parser_name.camelize}Parser".constantize
      rescue NameError
        return nil
      end

      def oauth_webui_uri
        return Ginseng::URI.parse(config["/#{name.underscore}/oauth/webui/url"]) rescue nil
      end

      def oauth_scopes(type = :default)
        return config["/#{name}/oauth/scopes/#{type}"].to_set
      rescue
        return Set[]
      end

      def oauth_client_name(type = :default)
        return nil unless oauth_scopes(type)
        type = type.to_sym
        name = [Package.name]
        name.push("(#{type})") unless type == :default
        return name.join(' ')
      end

      def status_field
        return config["/parser/#{parser_name}/fields/body"]
      end

      def visibility_field
        return config["/parser/#{parser_name}/fields/visibility"]
      end

      def reply_to_field
        return config["/parser/#{parser_name}/fields/reply_to"]
      end

      def poll_field
        return config["/parser/#{parser_name}/fields/poll/root"]
      end

      def poll_options_field
        return config["/parser/#{parser_name}/fields/poll/options"]
      end

      def spoiler_field
        return config["/parser/#{parser_name}/fields/spoiler"]
      end

      def chat_field
        return config["/#{name}/chat/field"] rescue nil
      end

      def attachment_field
        return config["/parser/#{parser_name}/fields/attachment"]
      end

      def visible_users_field
        return config["/parser/#{parser_name}/fields/visible_users"]
      end

      def status_key
        return config["/#{name}/status/key"]
      end

      def status_label
        return config["/#{name}/status/label"]
      end

      def status_delete_limit
        return config["/#{name}/status/delete/limit"] rescue nil
      end

      def default_image_type
        return config["/#{name}/attachment/types/image"] rescue nil
      end

      def default_video_type
        return config["/#{name}/attachment/types/video"] rescue nil
      end

      def default_audio_type
        return config["/#{name}/attachment/types/audio"] rescue nil
      end

      def default_animation_image_type
        return config["/#{name}/attachment/types/animation_image"] rescue nil
      end

      def visibility_name(name)
        return parser_class.visibility_name(name)
      end

      def schema
        return Config.load_file("schema/controller/#{name}")
      end

      def webhook_entries
        return Environment.access_token_class.webhook_entries
      end
    end
  end
end
