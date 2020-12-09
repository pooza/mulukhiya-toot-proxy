module Mulukhiya
  module Meisskey
    class Application < MongoCollection
      def self.[](id)
        return Application.new(id)
      end

      def scopes
        return permission
      end

      private

      def collection_name
        return :apps
      end
    end
  end
end
