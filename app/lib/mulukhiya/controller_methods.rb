module Mulukhiya
  module ControllerMethods
    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def name
        return to_s.split('::').last.sub(/Controller$/, '').underscore
      end

      def display_name
        return config["/#{name}/display_name"] rescue name
      end

      def webhook?
        return config["/#{name}/webhook"] == true rescue false
      end

      def media_catalog?
        return config["/#{name}/media_catalog"] == true rescue false
      end

      def feed?
        return config["/#{name}/feed"] rescue false
      end

      def growi?
        return Handler.search(/growi/).present?
      end

      def dropbox?
        return Handler.search(/dropbox/).present?
      end

      def announcement?
        return config["/#{name}/announcement"] == true rescue false
      end

      def filter?
        return config["/#{name}/filter"] == true rescue false
      end

      def futured_tag?
        return config["/#{name}/futured_tag"] == true rescue false
      end

      def annict?
        return false unless config["/#{name.underscore}/annict"] == true
        return false unless AnnictService.config?
        return true
      rescue Ginseng::ConfigError
        return false
      end

      def livecure?
        return false unless config['/programs/url'].present?
        return true
      rescue Ginseng::ConfigError
        return false
      end

      def dbms_name
        return config["/#{name}/dbms"]
      end

      def dbms_class
        return "Mulukhiya::#{dbms_name.camelize}".constantize
      end

      def parser_name
        return config["/#{name}/parser"]
      end

      def parser_class
        return "Mulukhiya::#{parser_name.camelize}Parser".constantize
      end

      def oauth_webui_uri
        return Ginseng::URI.parse(config["/#{name.underscore}/oauth/webui/url"]) rescue nil
      end

      def oauth_default_scopes
        return config["/#{name}/oauth/scopes"] || [] rescue nil
      end

      def status_field
        return config["/parser/#{parser_name}/fields/body"]
      end

      def poll_options_field
        return config["/parser/#{parser_name}/fields/poll/options"]
      end

      def spoiler_field
        return config["/parser/#{parser_name}/fields/spoiler"]
      end

      def attachment_field
        return config["/parser/#{parser_name}/fields/attachment"]
      end

      def status_key
        return config["/#{name}/status/key"]
      end

      def status_label
        return config["/#{name}/status/label"]
      end

      def visibility_name(name)
        return parser_class.visibility_name(name)
      end
    end
  end
end
