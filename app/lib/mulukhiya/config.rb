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
          info_bot: info_bot_profile,
          status_url: (self['/status_url'] rescue nil),
          founded_at: founded_at,
          preopened_at: preopened_at,
        },
      }
    end

    def audit
      local = raw['local']
      return {errors: [], unknown_keys: []} unless local.is_a?(Hash)
      return {
        errors: errors,
        unknown_keys: detect_unknown_keys(local, schema),
      }
    end

    private

    # サーバーの正式オープン日を ISO 8601 date (YYYY-MM-DD) で返す (#4434)。
    # `/founded_on` が設定されていればそれを、無ければ最古ローカルアカウントの
    # 作成日で近似する (capsicum はヒューリスティックを持たず /about を単純採用する)。
    # 取得不能・未設定・DB 未接続なら nil。
    def founded_at
      configured = self['/founded_on'] rescue nil
      return normalize_iso_date(configured) if configured.present?
      date = Environment.account_class&.founded_at
      return date&.to_date&.iso8601
    rescue
      return nil
    end

    # プレ公開（限定公開）を経たサーバーの、正式オープン前の公開開始日を ISO 8601
    # date で返す (#4434)。config `/preopened_on` が設定されている場合のみ値を返し、
    # プレ公開の無いサーバーでは nil。founded_at と違い最古アカウント fallback は
    # 持たない（プレ公開の有無は運用者しか知り得ず、最古アカウント≒プレ公開日を
    # 一律にプレ公開扱いすると誤りになるため）。
    def preopened_at
      return normalize_iso_date(self['/preopened_on'])
    rescue
      return nil
    end

    # config 値を ISO 8601 date (YYYY-MM-DD) 文字列へ正規化する。空は nil。
    # 設定済みだがパース不能（typo など）の場合は運用者の切り分け用に log を
    # 残して nil に倒す（未設定と typo を区別できるようにする）。alert はしない。
    def normalize_iso_date(value)
      return nil unless value.present?
      return Date.parse(value.to_s).iso8601
    rescue => e
      e.log(value: value.to_s)
      return nil
    end

    def detect_unknown_keys(data, sch, prefix = '')
      if data.is_a?(Array)
        item_sch = sch['items'] || {}
        return data.each_with_index.flat_map do |element, i|
          detect_unknown_keys(element, item_sch, "#{prefix}[#{i}]")
        end
      end
      return [] unless data.is_a?(Hash)
      props = sch['properties'] || {}
      return [] if props.empty?
      data.flat_map do |key, value|
        path = "#{prefix}/#{key}"
        if props.key?(key.to_s)
          detect_unknown_keys(value, props[key.to_s], path)
        else
          [path]
        end
      end
    end

    def info_bot_profile
      account = Environment.account_class&.info_account
      return nil unless account
      return {
        username: account.username,
        acct: account.acct.to_s,
        url: account.uri.to_s,
        display_name: account.display_name,
      }
    rescue
      return nil
    end

    def admin_role_ids
      return [] unless Environment.dbms_class&.config?
      if Environment.misskey?
        return Misskey::Role.where(isAdministrator: true).select_map(:id).map(&:to_s)
      end
      # rubocop:disable-next Style/BitwisePredicate, Style/NumericPredicate, Layout/SpaceInsideBlockBraces
      return Mastodon::Role.where { (permissions.sql_number & 1) > 0 }.select_map(:id).map(&:to_s)
    rescue
      return []
    end

    def sub_hash(prefix)
      return keys(prefix).to_h {|k| [k, self["#{prefix}/#{k}"]]}
    end
  end
end
