module Mulukhiya
  class Reporter < Array
    include Package

    attr_accessor :response, :parser
    attr_reader :temp, :tags, :errors

    def initialize(size = 0, val = nil)
      super
      @tags = TagContainer.new
      @temp = {}
      @errors = []
    end

    def push(entry)
      if entry.is_a?(Handler)
        # ⚠⚠ **`summary` は result と errors を 1 本に混ぜる (#4649)。**混ざった後では
        # 「どれが落ちたか」を取り出せないので、混ぜる前に控える。
        #
        # ⚠ **`reportable?` / `loggable?` とは無関係に必ず拾う。**あれらは
        # 「運用者へ通知する / ログへ出す」の判定で、**送信側への応答とは別の話**。
        # `notify_verbose?` が false のアカウントでも、落ちた添付は返す。
        @errors.concat(entry.errors.to_a)
        push(entry.summary) if entry.reportable?
        logger.info(entry.summary) if entry.loggable?
      elsif entry.present?
        super
        @dump = nil
      end
    end

    def to_h
      unless @dump
        @dump = {}
        each do |v|
          @dump[v[:event]] ||= {}
          @dump[v[:event]][v[:handler]] = v[:entries]
        end
      end
      return @dump
    end

    def to_s
      return to_h.to_yaml
    end
  end
end
