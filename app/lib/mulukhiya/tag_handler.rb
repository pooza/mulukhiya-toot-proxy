module Mulukhiya
  class TagHandler < Handler
    # addition_tags / removal_tags は 1 回だけ評価してローカルに束ねる (#4494)。
    # `result.push(addition_tags:)` の短縮記法は同名のローカルが無ければメソッド
    # 呼び出しになるため、素直に書くと if の分と合わせて 1 投稿に 3 回走る。
    # これらは純粋な getter ではなく Redis 読み・辞書スイープ・リモート照会を伴う。
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return unless executable?
      addition = addition_tags
      tags.merge(addition)
      result.push(addition_tags: addition) if addition.present?
      removal = removal_tags
      removal.each {|v| tags.delete(v)}
      result.push(removal_tags: removal) if removal.present?
    end

    def executable?
      return false if parser.command?
      return false if parser.accts.any?(&:agent?)
      return false if non_federated_payload?
      return true if payload[visibility_field].empty?
      return true if payload[visibility_field] == controller_class.visibility_name(:public)
      return false
    end

    def removal_tags
      return TagContainer.new
    end

    def addition_tags
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
