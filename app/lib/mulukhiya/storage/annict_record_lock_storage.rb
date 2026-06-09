module Mulukhiya
  # 同一 (account, episode) への createRecord 重複を TTL 窓で抑止する (#4330)。
  # 挙動は AnnictIdempotencyLockStorage に集約。
  class AnnictRecordLockStorage < AnnictIdempotencyLockStorage
    def prefix
      return 'annict_record_lock'
    end

    private

    def config_key
      return 'record'
    end

    def id_label
      return :episode_id
    end
  end
end
