module Mulukhiya
  module Mastodon
    class Poll < Sequel::Model(:polls)
      one_to_one :status

      def choices
        return values[:options].match(/\{(.*)\}/)[1].split(',')
      end

      alias options choices
    end
  end
end
