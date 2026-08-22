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
      # 内部 fetch に渡されたヘッダ。#4621 の検証に使う。
      attr_reader :source_headers, :status_headers

      def initialize(source, status)
        @source = source
        @status = status
      end

      def fetch_status_source(_id, params = {})
        @source_headers = params[:headers]
        return @source
      end

      def fetch_status(_id, params = {})
        @status_headers = params[:headers]
        return @status
      end
    end

    def create_controller(source: nil, status: nil, headers: nil)
      controller = MastodonController.new!
      controller.instance_variable_set(:@headers, headers || {})
      controller.instance_variable_set(:@sns, SnsDouble.new(
        source || {'text' => '本文', 'spoiler_text' => ''},
        status || {'sensitive' => false, 'media_attachments' => [{'id' => '111'}]},
      ))
      return controller
    end

    def build_body(source: nil, status: nil, params: nil, headers: nil)
      return create_controller(source:, status:, headers:).create_media_update_body(
        params || {id: '1', media_attributes: [{id: '111', description: 'ゴメちゃん'}]},
      )
    end

    def build_tag_body(source: nil, status: nil, params: nil)
      return create_controller(source:, status:).create_status_update_body(
        'tag',
        params || {id: '1', status: '本文 #新タグ'},
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

      assert_equal(['111', '222', '333'], body[:media_ids])
    end

    def test_media_ids_are_empty_without_attachments
      body = build_body(status: {'sensitive' => false})

      assert_empty(body[:media_ids])
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
      assert(build_body(status: {'sensitive' => true, 'media_attachments' => []})[:sensitive])
      refute(build_body(status: {'sensitive' => false, 'media_attachments' => []})[:sensitive])
    end

    # ⚠ false と nil を同一視しない。`.compact` で落とすと閲覧注意が意図せず動く。
    def test_sensitive_is_false_not_nil_when_absent
      body = build_body(status: {'media_attachments' => []})

      # ⚠ refute だけだと nil でも通ってしまうので、型で false を名指しする。
      assert_instance_of(FalseClass, body[:sensitive])
    end

    # ⚠⚠ **本文が空の投稿では `spoiler_text` を送らない (#4623)。**
    # Mastodon の `update_immediate_attributes!` は本文が blank のとき
    # `@options.delete(:spoiler_text)` を**本文へ昇格**させる。しかも `delete` 済みなので
    # 次の行の `key?(:spoiler_text)` が false になり **CW も残る**＝本文と CW に
    # 同じ文言が並ぶ。キーごと落とせば本文は空のまま・CW は現状維持になる。
    def test_spoiler_text_is_omitted_when_status_is_blank
      body = build_body(source: {'text' => '', 'spoiler_text' => 'ネタバレ'})

      # ⚠ nil ではなく**キーが無い**こと。nil でも gem の compact で落ちるが、
      # 「送らない」を型で示す。
      refute(body.key?(:spoiler_text))
      assert_equal('', body[:status])
    end

    # ⚠ **本文があるときは従来どおり送る (#4589)。**落とすと CW が消える。
    def test_spoiler_text_is_sent_when_status_is_present
      body = build_body(source: {'text' => '本文', 'spoiler_text' => 'ネタバレ'})

      assert_equal('ネタバレ', body[:spoiler_text])
    end

    # ⚠⚠ **アンケートを持つ投稿は編集を断る (#4625)。**Mastodon は `poll` を
    # 送らなければ **票ごと destroy** する一方、送って復元することもできない
    # （`hide_totals` を REST が返さない・残り 5 分未満と期限切れは検証に落ちる）。
    # 「隠した票が見える」「票が消える」より断るほうが安全。
    def test_status_with_poll_is_refused
      assert_raise(Ginseng::ValidateError) do
        build_body(status: {
          'sensitive' => false,
          'media_attachments' => [],
          'poll' => {'expired' => false, 'options' => [{'title' => 'キュア'}]},
        })
      end
    end

    def test_tag_body_refuses_status_with_poll
      assert_raise(Ginseng::ValidateError) do
        build_tag_body(status: {
          'sensitive' => false,
          'media_attachments' => [],
          'poll' => {'expired' => true, 'options' => []},
        })
      end
    end

    # アンケートが無ければ `poll` は送らない（送ると上流が作りに行く）。
    def test_poll_is_absent_without_poll
      refute(build_body.key?(:poll))
    end

    # ⚠⚠ **`tag` purpose も同じ復元を通す (#4625)。**#4589 は ALT 編集側しか
    # 直しておらず、こちらは `status` と `media_attributes` しか送っていなかったため
    # **添付が全部外れ・CW が消え・閲覧注意が外れ**ていた。
    def test_tag_body_restores_everything
      body = build_tag_body(
        source: {'text' => 'もとの本文', 'spoiler_text' => 'ネタバレ'},
        status: {
          'sensitive' => true,
          'media_attachments' => [{'id' => '111'}, {'id' => '222'}],
        },
      )

      assert_equal(['111', '222'], body[:media_ids])
      assert_equal('ネタバレ', body[:spoiler_text])
      assert(body[:sensitive])
    end

    # ⚠ **`status` だけは呼び出し側のものを使う。**タグを付け替えた本文を
    # 送り直すのがこの経路の目的なので、そこを復元してはいけない。
    def test_tag_body_uses_given_status
      body = build_tag_body(source: {'text' => 'もとの本文', 'spoiler_text' => ''})

      assert_equal('本文 #新タグ', body[:status])
    end

    # ⚠ **`status` 省略時は復元した本文を使う。**素朴に compact すると
    # `status` が落ち、Mastodon 側で `@status.text = ''` ＝ **本文まで空になる**。
    def test_tag_body_falls_back_to_restored_status
      body = build_tag_body(
        source: {'text' => 'もとの本文', 'spoiler_text' => ''},
        params: {id: '1', media_attributes: [{id: '111'}]},
      )

      assert_equal('もとの本文', body[:status])
    end

    # ⚠ **内部 fetch にクライアントの `X-Mulukhiya-Purpose` を持ち込まない (#4621)。**
    # Purpose は nginx への名乗りであって上流に意味は無く、#4474 以前の
    # `if ($http_x_mulukhiya_purpose != '')` が残った vhost では内部 fetch が
    # モロヘイヤへ送り返されてループする（ステージングで実際に起きた）。
    def test_purpose_is_not_carried_into_internal_fetch
      controller = create_controller(headers: {
        'Authorization' => 'Bearer ゴメちゃん',
        'X-Mulukhiya-Purpose' => 'media_update',
      })
      controller.create_media_update_body({id: '1', media_attributes: [{id: '111'}]})
      sns = controller.instance_variable_get(:@sns)

      refute(sns.source_headers.key?('X-Mulukhiya-Purpose'))
      refute(sns.status_headers.key?('X-Mulukhiya-Purpose'))
    end

    # ⚠ **Authorization まで落とさない。** 内部 fetch は利用者のトークンで
    # 読みに行くので、これが欠けると自分の投稿すら 404 になる。
    def test_authorization_survives_in_internal_fetch
      controller = create_controller(headers: {
        'Authorization' => 'Bearer ゴメちゃん',
        'X-Mulukhiya-Purpose' => 'media_update',
      })
      controller.create_media_update_body({id: '1', media_attributes: [{id: '111'}]})
      sns = controller.instance_variable_get(:@sns)

      assert_equal('Bearer ゴメちゃん', sns.source_headers['Authorization'])
      assert_equal('Bearer ゴメちゃん', sns.status_headers['Authorization'])
    end

    # ⚠ **呼び元の @headers を壊さない。**`token` が同じハッシュを読むので、
    # 破壊的に消すと以後の照合が変わる。
    def test_original_headers_are_not_mutated
      headers = {'X-Mulukhiya-Purpose' => 'media_update'}
      controller = create_controller(headers:)
      controller.create_media_update_body({id: '1', media_attributes: [{id: '111'}]})

      assert_equal('media_update', headers['X-Mulukhiya-Purpose'])
    end
  end
end
