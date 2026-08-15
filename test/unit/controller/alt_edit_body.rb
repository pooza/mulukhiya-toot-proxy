module Mulukhiya
  # ALT 編集 (`PUT /api/:version/statuses/:id`) が SNS へ送る body (#4589)。
  #
  # ⚠ **眼目は「現状維持したい値も送り直す」こと。** Mastodon の
  # `UpdateStatusService` は「送らなかったパラメータ」を現状維持ではなく
  # **「空で更新」**として扱う（`options.key?` で分岐し、コントローラの
  # `update_options` がハッシュリテラルなのでキーは常に存在する）。
  #
  # そのため、ここで欠けると ALT が反映されないどころか投稿が壊れる:
  #
  # - `media_ids` … ALT が適用されないうえ **投稿から添付が全部外れる**
  # - `spoiler_text` … **CW が消える**
  # - `sensitive` … **閲覧注意フラグが外れる**
  class AltEditBodyTest < TestCase
    # `fetch_status_source` / `fetch_status` だけ返す SNS のダブル。
    class SnsDouble
      def initialize(source, status)
        @source = source
        @status = status
      end

      def fetch_status_source(_id, _params = {})
        return @source
      end

      def fetch_status(_id, _params = {})
        return @status
      end
    end

    def build_body(source: nil, status: nil, params: nil)
      controller = MastodonController.new!
      controller.instance_variable_set(:@headers, {})
      controller.instance_variable_set(:@sns, SnsDouble.new(
        source || {'text' => '本文', 'spoiler_text' => ''},
        status || {'sensitive' => false, 'media_attachments' => [{'id' => '111'}]},
      ))
      return controller.create_media_update_body(
        params || {id: '1', media_attributes: [{id: '111', description: 'ゴメちゃん'}]},
      )
    end

    def test_media_attributes_are_passed_through
      body = build_body

      assert_equal([{id: '111', description: 'ゴメちゃん'}], body[:media_attributes])
    end

    # 本文は `/source` の生テキストから戻す。status entity の `content` は HTML
    # なので、そちらを使うと投稿本文が HTML へ置き換わる。
    def test_status_comes_from_source_text
      body = build_body(source: {'text' => 'もとの本文', 'spoiler_text' => ''})

      assert_equal('もとの本文', body[:status])
    end

    # 添付が外れないために必須。**順序も保つ**（ordered_media_attachment_ids に
    # そのまま入るので、入れ替えると投稿内の並びが変わる）。
    def test_media_ids_are_restored_in_order
      body = build_body(
        status: {
          'sensitive' => false,
          'media_attachments' => [{'id' => '111'}, {'id' => '222'}, {'id' => '333'}],
        },
      )

      assert_equal(%w[111 222 333], body[:media_ids])
    end

    def test_media_ids_are_empty_without_attachments
      body = build_body(status: {'sensitive' => false})

      assert_equal([], body[:media_ids])
    end

    # CW を消さないために必須。`/source` が返しているのに使っていなかった。
    def test_spoiler_text_is_restored
      body = build_body(source: {'text' => '本文', 'spoiler_text' => 'ネタバレ'})

      assert_equal('ネタバレ', body[:spoiler_text])
    end

    # ⚠ CW 無しは nil ではなく空文字で送る。nil だと `.compact` 等で落ちうるし、
    # 落ちれば Mastodon 側で「空で更新」になり結局同じ値になるとはいえ、
    # 「送っている」ことを型で示しておく。
    def test_spoiler_text_is_empty_string_when_absent
      body = build_body(source: {'text' => '本文'})

      assert_equal('', body[:spoiler_text])
    end

    def test_sensitive_is_restored
      assert_equal(true, build_body(status: {'sensitive' => true, 'media_attachments' => []})[:sensitive])
      assert_equal(false, build_body(status: {'sensitive' => false, 'media_attachments' => []})[:sensitive])
    end

    # ⚠ false と nil を同一視しない。`.compact` で落とすと閲覧注意が意図せず動く。
    def test_sensitive_is_false_not_nil_when_absent
      body = build_body(status: {'media_attachments' => []})

      assert_equal(false, body[:sensitive])
      assert(body.key?(:sensitive))
    end
  end
end
