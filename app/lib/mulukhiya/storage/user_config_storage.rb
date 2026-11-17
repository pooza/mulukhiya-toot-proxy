module Mulukhiya
  class UserConfigStorage < Redis
    def [](key)
      return JSON.parse(get(key)).key_flatten
    end

    def get(key)
      return super || '{}'
    end

    def set(key, values)
      super(key, values.except('c', 'command').to_json)
      save
    end

    # 書いた設定をディスクへ残す。
    # ⚠ 同期の `SAVE` は使わない（5.47.0 のリリース前レビュー）。サーバー全体を止めるうえ、定期の BGSAVE と
    # 重なると `ERR Background save already in progress` で失敗し、**書けているのに**要求が 500 になっていた
    # （設定画面はチェックを戻すので、画面と保存された値が逆になる）。`SCHEDULE` は実行中なら終わってから取る。
    # ⚠ 失敗しても SET は済んでいるので、要求は失敗させない。残せなくても次の定期の保存で残る。
    def save
      return redis.call('BGSAVE', 'SCHEDULE')
    rescue => e
      e.log(storage: underscore)
      return nil
    end

    def update(key, values)
      values.deep_stringify_keys!
      if values.key?('tags')
        values['tagging'] ||= {}
        values['tagging']['user_tags'] ||= values['tags']
        values.delete('tags')
      end
      set(key, JSON.parse(get(key)).deep_merge(values).deep_compact)
    end

    def prefix
      return 'user'
    end

    def self.clear_tags
      bar = ProgressBar.create(total: accounts.count)
      tag_owners do |account|
        account.user_config.clear_tags
      ensure
        bar&.increment
      end
      bar&.finish
    end

    def self.clean
      bar = ProgressBar.create(total: accounts.count)
      accounts do |account|
        removed = account.user_config.clean
        next unless removed.present?
        logger.info(account: account.acct.to_s, removed:)
      ensure
        bar&.increment
      end
      bar&.finish
    end

    def self.tag_owners(&block)
      return enum_for(__method__) unless block
      accounts.select {|v| v.user_config['/tagging/user_tags'].present?}.each(&block)
    end

    def self.decoration_owners(&block)
      return enum_for(__method__) unless block
      accounts.select {|v| v.user_config['/decoration/saved_state'].present?}.each(&block)
    end

    def self.accounts(&block)
      return enum_for(__method__) unless block
      new.all_keys
        .map {|key| key.split(':').last}
        .filter_map {|id| Environment.account_class[id] rescue nil}
        .each(&block)
    end
  end
end
