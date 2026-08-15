module Mulukhiya
  # `PUT /api/:version/statuses/:id` の必須パラメータ検証 (#4589)。
  #
  # ⚠ **purpose ごとに必須が違う。** ALT 編集（nil / `''` / `media_update`）は
  # `media_attributes` が必須だが、`tag` は**タグを付け替えた本文を送り直す経路**
  # なので添付を持たない投稿にも来る。一律に要求すると本文だけのタグ書き換えが
  # 422 になる（PR #4590 の Codex P2）。
  class StatusUpdateValidationTest < TestCase
    def validate(purpose, params)
      return MastodonController.new!.validate_status_update!(purpose, params)
    end

    def test_unknown_purpose_is_rejected
      assert_raise(Ginseng::ValidateError) do
        validate('destroy', {media_attributes: [{id: '111'}]})
      end
    end

    # nginx を経由しない直接アクセス（実質モロヘイヤ自身の転送）。
    def test_blank_purpose_is_accepted
      assert_nothing_raised {validate(nil, {media_attributes: [{id: '111'}]})}
      assert_nothing_raised {validate('', {media_attributes: [{id: '111'}]})}
    end

    def test_media_update_requires_media_attributes
      assert_nothing_raised do
        validate('media_update', {media_attributes: [{id: '111', description: 'ゴメちゃん'}]})
      end
      assert_raise(Ginseng::ValidateError) {validate('media_update', {status: '本文'})}
      assert_raise(Ginseng::ValidateError) {validate('media_update', {media_attributes: []})}
    end

    # ⚠ 本件の眼目。`tag` は `status` だけで通る。
    def test_tag_accepts_status_without_media_attributes
      assert_nothing_raised {validate('tag', {status: '本文 #キュアスタ'})}
    end

    def test_tag_accepts_media_attributes_without_status
      assert_nothing_raised {validate('tag', {media_attributes: [{id: '111'}]})}
    end

    # 両方無いときだけ弾く（元の `body.empty?` と同じ線引き）。
    def test_tag_rejects_empty_payload
      assert_raise(Ginseng::ValidateError) {validate('tag', {id: '1'})}
    end
  end
end
