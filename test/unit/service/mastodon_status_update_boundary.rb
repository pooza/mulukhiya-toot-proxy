module Mulukhiya
  # gem 境界のテスト (#4621)。
  #
  # ALT 編集の `PUT /api/v1/statuses/:id` で、**`media_attributes` が Hash の
  # 配列のまま上流へ届くか**は gem 側の組み立てに握られている。かつて
  # ginseng-fediverse は `media_attributes[0][id]=...` と**数字の添字**で
  # form-urlencode しており、この形は Rack / Rails 側で `fields_for` 形式の
  # Hash `{"0" => {...}}` に解釈され**配列にならなかった**。Mastodon の
  # `UpdateStatusService` は `(@options[:media_attributes] || []).each` と回すので
  # `["0", {...}]`（Array）を掴み、`attributes[:id]` で
  # `TypeError: no implicit conversion of Symbol into Integer` ＝ **500** になった
  # (pooza/ginseng-fediverse#253)。
  #
  # ⚠ `alt_edit_body` は**モロヘイヤが組んだ Hash** しか見ないので、この退行を
  # 捕まえられない。**gem が組んだリクエスト**を押さえるのがこのファイルの役目。
  # `bundle update` で黙って戻る類なので、境界の契約として残す。
  class MastodonStatusUpdateBoundaryTest < TestCase
    # PUT の引数を捕まえるだけの http スタブ。
    class CapturingHTTP
      attr_reader :options

      def put(_uri, options = {})
        @options = options
        return nil
      end
    end

    def update(body)
      http = CapturingHTTP.new
      service = Ginseng::Fediverse::MastodonService.new(Ginseng::URI.parse('https://precure.ml/'))
      service.instance_variable_set(:@http, http)
      service.update_status('111', body)
      return http.options
    end

    # ⚠ ginseng-core の `create_body` は Content-Type が JSON のときだけ
    # `to_json` する。無指定だと HTTParty が Hash を form-urlencode し、
    # そこでも数字の添字（HashConversions#to_params）になって同じ 500 に戻る。
    def sent_body(options)
      return JSON.parse(options[:body].to_json)
    end

    def test_content_type_is_json
      options = update({media_attributes: [{id: '111', description: 'ゴメちゃん'}]})

      assert_equal('application/json', options[:headers]['Content-Type'])
    end

    # 眼目。Hash の配列でないと Mastodon が 500 を返す。
    def test_media_attributes_reach_upstream_as_array_of_hashes
      options = update({
        media_attributes: [
          {id: '111', description: 'ゴメちゃん'},
          {id: '222', description: 'ダイの大冒険'},
        ],
      })

      assert_equal(
        [
          {'id' => '111', 'description' => 'ゴメちゃん'},
          {'id' => '222', 'description' => 'ダイの大冒険'},
        ],
        sent_body(options)['media_attributes'],
      )
    end

    # ⚠ 平坦化の痕跡が残っていないこと。キーとしては通っても配列にならない。
    # ⚠ **percent-encode を解いてから見る。**form-urlencoded の body は
    # `media_attributes%5B0%5D%5Bid%5D` になるので、生のまま探すと素通りする。
    def test_flattened_keys_are_gone
      options = update({media_attributes: [{id: '111'}]})

      refute_includes(
        ::URI.decode_www_form_component(options[:body].to_json),
        'media_attributes[0]',
      )
    end

    # #4589 の不変条件。落とすと投稿から添付が全部外れ、CW と閲覧注意が消える。
    def test_restored_fields_reach_upstream
      options = update({
        status: '本文',
        spoiler_text: 'ネタバレ',
        sensitive: false,
        media_ids: ['111', '222'],
        media_attributes: [{id: '111'}],
      })
      body = sent_body(options)

      assert_equal('本文', body['status'])
      assert_equal('ネタバレ', body['spoiler_text'])
      assert_equal(['111', '222'], body['media_ids'])
      # ⚠ refute だけだと nil でも通る。キーの存在と対で見る。
      refute(body['sensitive'])
      assert(body.key?('sensitive'))
    end
  end
end
