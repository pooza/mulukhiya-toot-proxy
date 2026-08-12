module Mulukhiya
  class RSS20FeedRenderer < Ginseng::Web::RSS20FeedRenderer
    include Package
    include SNSMethods

    attr_accessor :command, :render_storage, :metadata_storage

    def initialize(channel = {})
      super
      @http.retry_limit = 1
      @sns = sns_class.new
      @channel[:author] = @sns.maintainer_name
      @render_storage = RenderStorage.new
      @render_storage.ttl = config['/feed/cache/ttl']
      @metadata_storage = MediaMetadataStorage.new
    end

    def cache
      raise Ginseng::NotFoundError, 'Not Found' unless command
      command.exec
      unless command.status.zero?
        raise Ginseng::Error,
          "CustomFeed command failed (exit #{command.status}): #{command.stderr}"
      end
      self.entries = parse_entries(command.stdout)
      render_storage[command] = render
    end

    alias save cache

    # 相対 URL を base で絶対化する (#4549)。絶対化できなければ nil。
    #
    # ⚠ インスタンスメソッドにしない。インスタンスは SNS (DB) と Redis を掴むので、
    # DB の無い環境ではテストがケースごと omit され、**この判定が一度も走らない**。
    def self.absolute_uri(value, base)
      return nil if value.blank?
      uri = Ginseng::URI.parse(value.to_s)
      return uri.to_s if uri.absolute?
      return nil if base.blank?
      return ::URI.join(base.to_s, value.to_s).to_s
    rescue
      # 相対解決に失敗する値 (制御文字入り等) は enclosure ごと落とす。
      return nil
    end

    def clear
      render_storage.unlink(command)
    end

    def to_s
      return render(log: false) unless render_storage.key?(command)
      return render_storage[command]
    rescue => e
      e.log
      return render(log: false)
    end

    private

    # 1 レンダーぶんの描画 (#4560)。
    #
    # ⚠ **unresolved はレンダーごとに捨てる。**レンダラは CustomFeed#renderer が
    # メモ化するので、貯めるとリクエストのたびに配列が伸び、後続の
    # log_unresolved_enclosures が「そのレンダーぶん」でなく累積の count / sample を
    # 報告する。
    #
    # ⚠ **リクエスト経路 (log: false) ではログを出さない。**5 分おきの更新側が
    # 1 サイクル 1 行で出すので十分で、リクエストごとに出すと #4549 の再来になる。
    def render(log: true)
      unresolved_enclosures.clear
      rendered = feed.to_s
      log_unresolved_enclosures if log
      return rendered
    end

    def parse_entries(stdout)
      entries = JSON.parse(stdout)
      return entries if entries.is_a?(Array)
      raise Ginseng::Error, "CustomFeed command returned non-array (#{entries.class})"
    rescue JSON::ParserError, Ginseng::Error => e
      e.log
      return []
    end

    # ⚠ 相対 URL はここで絶対化する (#4549)。
    #
    # 基底クラスは `@http.base_uri = channel[:link]` を置いて Ginseng::HTTP#create_uri に
    # 解決させていたが、こちらは fetch_image を上書きして MediaMetadataStorage
    # (base_uri を持たない別の HTTP) へ委譲したので、その解決だけが落ちていた。
    # サイト相対の画像 URL を返すフィード (dqdai-anime) は **サムネイルが全滅**したうえ、
    # 5 分おきに `base_uri undefined` をエントリ数ぶん吐き続けていた (日 2 万行)。
    def fetch_image(uri)
      return nil unless uri = absolute_uri(uri)
      metadata_storage.push(uri) unless metadata_storage.key?(uri)
      return metadata_storage[uri]
    rescue => e
      e.log(uri: uri.to_s)
      return nil
    end

    # channel の link を基準に絶対 URL へ寄せる。絶対化できない値は nil を返して
    # enclosure ごと落とす (壊れた URL を enclosure に載せない)。
    def absolute_uri(value)
      return nil if value.blank?
      return self.class.absolute_uri(value, @http.base_uri) || unresolved_enclosure(value)
    end

    # 絶対化できなかった値を覚えておく。⚠ **ここで 1 件ずつログを出さない。**
    # エントリごとに出すと 5 分おきにエントリ数ぶん積み上がる (#4549 の再来)。
    # まとめて 1 行にするのは log_unresolved_enclosures の仕事。
    def unresolved_enclosure(value)
      unresolved_enclosures.push(value.to_s)
      return nil
    end

    def unresolved_enclosures
      @unresolved_enclosures ||= []
      return @unresolved_enclosures
    end

    def log_unresolved_enclosures
      return if unresolved_enclosures.empty?
      logger.warn(
        message: 'feed enclosure url unresolved',
        link: channel[:link].to_s,
        count: unresolved_enclosures.size,
        sample: unresolved_enclosures.first,
      )
    end
  end
end
