module Mulukhiya
  module Mastodon
    class Role < Sequel::Model(:user_roles)
      def admin?
        return permissions.anybits?(1)
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
