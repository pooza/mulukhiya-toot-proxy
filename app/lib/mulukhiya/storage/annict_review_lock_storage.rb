module Mulukhiya
  # 同一 (account, work_id) への createReview 重複を TTL 窓で抑止する (#4342)。
  # 挙動は AnnictIdempotencyLockStorage に集約。
  class AnnictReviewLockStorage < AnnictIdempotencyLockStorage
    def prefix
      return 'annict_review_lock'
    end

    private

    def config_key
      return 'review'
    end

    def id_label
      return :work_id
    end
  end
end
