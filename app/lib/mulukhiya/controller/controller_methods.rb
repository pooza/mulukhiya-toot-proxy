module Mulukhiya
  module ControllerMethods
    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def webhook?
        return config["/#{name.underscore}/webhook"] == true
      rescue Ginseng::ConfigError
        return false
      end

      def tag_feed?
        return config["/#{name.underscore}/tag_feed"] && TagContainer.default_tags.present?
      rescue Ginseng::ConfigError
        return false
      end

      def clipping?
        return config["/#{name.underscore}/clipping"] == true
      rescue Ginseng::ConfigError
        return false
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

      def self.twitter?
        return config["/#{name.underscore}/twitter"] && TwitterService.config?
      rescue Ginseng::ConfigError
        return false
      end

      def self.annict?
        return config["/#{name.underscore}/annict"] && AnnictService.config?
      rescue Ginseng::ConfigError
        return false
      end

      def livecure?
        return config['/webui/livecure'] == true
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

      def events
        return config["/#{name.underscore}/events"].map(&:to_sym)
      end
    end
  end
end
