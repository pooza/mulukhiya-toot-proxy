module Mulukhiya
  class Config < Ginseng::Config
    include Package

    def disable?(handler)
      handler = Handler.create(handler.to_s) unless handler.is_a?(Handler)
      return self["/handler/#{handler.underscore}/disable"] == true rescue false
    end

    def schema
      unless @schema
        @schema = self.class.load_file('schema/base').deep_symbolize_keys
        @schema[:properties].merge!(
          Environment.controller_name.to_sym => Environment.controller_class.schema,
          :handler => Handler.all_schema,
        )
        @schema[:required].push('controller') unless Environment.controller_name == 'mastodon'
        @schema[:required].push(Environment.controller_name)
        @schema[:required].push(Environment.dbms_name) if Environment.dbms_class&.config?
        @schema.deep_stringify_keys!
      end
      return @schema
    end

    def about
      controller = Environment.controller_class
      name = Environment.controller_name
      return {
        package: raw.dig('application', 'package'),
        config: {
          controller: self['/controller'],
          status: Environment.status_class.default.merge(
            label: controller.status_label,
            reblog_label: controller.reblog_label,
            max_length: controller.max_length,
          ),
          capabilities: sub_hash("/#{name}/capabilities"),
          features: sub_hash("/#{name}/features"),
          admin_role_ids: admin_role_ids,
        },
      }
    end

    private

    def admin_role_ids
      return [] unless Environment.dbms_class&.config?
      if Environment.misskey?
        return Misskey::Role.where(isAdministrator: true).select_map(:id).map(&:to_s)
      end
      # rubocop:disable Style/BitwisePredicate, Style/NumericPredicate, Layout/SpaceInsideBlockBraces
      return Mastodon::Role.where { (permissions.sql_number & 1) > 0 }.select_map(:id).map(&:to_s)
      # rubocop:enable Style/BitwisePredicate, Style/NumericPredicate, Layout/SpaceInsideBlockBraces
    rescue
      return []
    end

    def sub_hash(prefix)
      return keys(prefix).to_h {|k| [k, self["#{prefix}/#{k}"]]}
    end
  end
end
