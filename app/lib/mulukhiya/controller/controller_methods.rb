module Mulukhiya
  module ControllerMethods
    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def display_name
        return config["/#{name.underscore}/display_name"] || name
      rescue Ginseng::ConfigError
        return name
      end

      def webhook?
        return config["/#{name.underscore}/webhook"] == true
      rescue Ginseng::ConfigError
        return false
      end

      def media_catalog?
        return config["/#{name.underscore}/media_catalog"] == true
      rescue Ginseng::ConfigError
        return false
      end

      def feed?
        return config["/#{name.underscore}/feed"]
      rescue Ginseng::ConfigError
        return false
      end

      def growi?
        return Handler.search(/growi/).present?
      end

      def dropbox?
        return Handler.search(/dropbox/).present?
      end

      def announcement?
        return config["/#{name.underscore}/announcement"] == true
      rescue Ginseng::ConfigError
        return false
      end

      def filter?
        return config["/#{name.underscore}/filter"] == true
      rescue Ginseng::ConfigError
        return false
      end

      def futured_tag?
        return config["/#{name.underscore}/futured_tag"] == true
      rescue Ginseng::ConfigError
        return false
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

      def parser_name
        return config["/#{name.underscore}/parser"]
      rescue Ginseng::ConfigError
        return false
      end

      def dbms_name
        return config["/#{name.underscore}/dbms"]
      end

      def parser_class
        return "Mulukhiya::#{parser_name.camelize}Parser".constantize
      end

      def dbms_class
        return "Mulukhiya::#{dbms_name.camelize}".constantize
      end

      def postgres?
        return dbms_name == 'postgres'
      end

      def mongo?
        return dbms_name == 'mongo'
      end

      def status_field
        return config["/parser/#{parser_name}/fields/body"]
      end

      def oauth_webui_uri
        return Ginseng::URI.parse(config["/#{name.underscore}/oauth/webui/url"])
      rescue Ginseng::ConfigError
        return nil
      end

      def oauth_default_scopes
        return config["/#{name.underscore}/oauth/scopes"] || []
      rescue Ginseng::ConfigError
        return nil
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
        return config["/#{name.underscore}/status/key"]
      end

      def visibility_name(name)
        return parser_class.visibility_name(name)
      end

      def status_label
        return config["/#{name.underscore}/status/label"]
      end

      def event_syms
        return config.keys("/#{name.underscore}/handlers").map(&:to_sym)
      end
    end
  end
end
