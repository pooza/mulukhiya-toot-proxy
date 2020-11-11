module Mulukhiya
  module Refines
    class ::String
      def escape_toot
        return sub(/[@#]/, '\\0 ')
      end

      alias escape_note escape_toot
    end
  end
end
