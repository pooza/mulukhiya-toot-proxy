module Mulukhiya
  # 409 の「恒久／一過性」をクライアントが文言に頼らず判別できること (#4579)。
  #
  # ⚠⚠ 以前は 409 がすべて `{"error": "<日本語文>"}` で、**文言を推敲した瞬間に
  # クライアントのリトライ判定が黙って壊れる**形だった。
  class ConflictCodeTest < TestCase
    def setup
      @controller = APIController.new!
      @renderer = Ginseng::Web::JSONRenderer.new
      @controller.instance_variable_set(:@renderer, @renderer)
      @controller.instance_variable_set(:@response, Sinatra::Response.new)
    end

    # ロック競合は待てば通るので、code と Retry-After の両方を付ける。
    def test_lock_conflict_has_code_and_retry_after
      render(ConflictError.new('別の更新が進行中です。', code: :locked, retry_after: 30))

      assert_equal(409, @renderer.status)
      assert_equal('locked', body[:code])
      assert_equal('別の更新が進行中です。', body[:error])
      assert_equal('30', retry_after)
    end

    # ⚠ 恒久の 409 に Retry-After を付けない。付けると「待てば通る」と読まれる。
    def test_permanent_conflict_has_no_retry_after
      render(ConflictError.new('自動更新が有効のため、編集できません。', code: :auto_update))

      assert_equal('auto_update', body[:code])
      assert_nil(retry_after)
    end

    # ⚠⚠ Annict の二重送信は一過性ではない（先の要求が成功していれば、待って送り
    # 直すと二重に記録される）。Retry-After を付けない。
    def test_duplicate_request_has_no_retry_after
      render(ConflictError.new('Duplicate Annict record request is in progress', code: :duplicate_request))

      assert_equal('duplicate_request', body[:code])
      assert_nil(retry_after)
    end

    # 理由を持たない例外の応答は従来どおり（上流透過 #4480 などと形を変えない）。
    def test_plain_error_keeps_the_legacy_shape
      render(Ginseng::NotFoundError.new('Not Found'))

      assert_equal(404, @renderer.status)
      assert_equal({error: 'Not Found'}, @renderer.message)
      assert_nil(retry_after)
    end

    # ⚠ `error do` の受け皿は `to_h` から本文を組むので、そちらでも `code` が残ること。
    def test_code_survives_to_h
      error = ConflictError.new('別の更新が進行中です。', code: :locked, retry_after: 30)

      assert_equal('locked', error.to_h[:code])
    end

    def test_unknown_code_is_rejected
      assert_raise(ArgumentError) {ConflictError.new('x', code: :whatever)}
    end

    # 既存の `rescue Ginseng::ConflictError` がそのまま効くこと。
    def test_is_a_ginseng_conflict_error
      error = ConflictError.new('x', code: :locked)

      assert_kind_of(Ginseng::ConflictError, error)
      assert_equal(409, error.status)
    end

    # ログでも 3 種類を分ける。message は自由文なので集計に使えない。
    def test_program_entry_conflict_is_logged_with_reason
      logged = capture_info do
        @controller.send(
          :handle_program_entry_error,
          ConflictError.new("キー 'precure' は既に存在します。", code: :duplicate_key),
          'precure',
        )
      end

      assert_equal('duplicate_key', logged.first[:program_entry][:reason])
    end

    private

    def render(error)
      @controller.send(:render_error, error)
    end

    def body
      return @renderer.message.transform_keys(&:to_sym)
    end

    def retry_after
      return @controller.response.headers['Retry-After']
    end

    def capture_info
      logged = []
      double = Object.new
      double.define_singleton_method(:info) {|payload| logged.push(payload)}
      Logger.define_singleton_method(:new) {|*| double}
      begin
        yield
      ensure
        # ⚠ 元の `new` は `Class#new` で、特異メソッドではない。定義し直して戻すと
        # 特異メソッドが残るので、外して `Class#new` へ戻す。
        Logger.singleton_class.send(:remove_method, :new)
      end
      return logged
    end
  end
end
