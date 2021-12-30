module Mulukhiya
  module Meisskey
    class Application < MongoCollection
      def self.[](id)
        return new(id)
      end

      def scopes
        return permission.to_set
      end

      private

      def collection_name
        return :apps
      end
    end
  end
end
