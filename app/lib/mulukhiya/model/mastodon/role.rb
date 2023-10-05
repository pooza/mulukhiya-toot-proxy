module Mulukhiya
  module Mastodon
    class Role < Sequel::Model(:user_roles)
      def admin?
        return (permissions & 1).positive?
      end

      alias visible? highlighted

      def to_h
        return values.deep_symbolize_keys.merge(
          is_admin: admin?,
          is_visible: visible?,
        ).compact
      end
    end
  end
end
