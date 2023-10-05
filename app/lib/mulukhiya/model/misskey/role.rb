module Mulukhiya
  module Misskey
    class Role < Sequel::Model(:role)
      alias admin? isAdministrator

      alias visible? asBadge

      def to_h
        return values.deep_symbolize_keys.merge(
          is_admin: admin?,
          is_visible: visible?,
        ).compact
      end
    end
  end
end
