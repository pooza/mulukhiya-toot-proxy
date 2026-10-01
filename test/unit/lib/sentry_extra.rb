module Mulukhiya
  # alert の付帯情報を、伏せ字を通して Sentry の extra へ載せる (#4745)。
  class SentryExtraTest < TestCase
    def test_keeps_diagnostic_values
      extra = SentryExtra.create(
        redis_key: 'tagging_dictionary',
        sources: 3,
        cached_entries: 0,
        generated_at: '2026-09-21T10:00:00+09:00',
      )

      assert_equal(3, extra[:sources])
      assert_equal(0, extra[:cached_entries])
      assert_equal('tagging_dictionary', extra[:redis_key])
      assert_equal('2026-09-21T10:00:00+09:00', extra[:generated_at])
    end

    # syslog と同じ Logger のマスク（キー名）。
    def test_masks_credential_keys
      extra = SentryExtra.create(token: 'secret-token-value', password: 'hunter2')

      assert_not_match(/secret-token-value/, extra.to_s)
      assert_not_match(/hunter2/, extra.to_s)
    end

    # syslog と同じ Logger のマスク（URL のクエリ）。
    def test_masks_credential_query_params
      extra = SentryExtra.create(url: 'https://example.com/api?access_token=abcdef123456')

      assert_not_match(/abcdef123456/, extra.to_s)
    end

    # LogScrubber の対象（本文系・OAuth コード・ボディの i）は、入れ子でも落ちる。
    def test_scrubs_body_fields
      extra = SentryExtra.create(
        program_entry: {status: '本文です', code: 'oauth-code', i: 'misskey-token'},
        blocks: [{text: {text: '入れ子の本文'}}],
      )

      assert_not_match(/本文です|oauth-code|misskey-token|入れ子の本文/, extra.to_s)
      assert_equal('[FILTERED]', extra.dig(:program_entry, :status))
    end

    def test_does_not_modify_values
      values = {program_entry: {status: '本文です'}}
      SentryExtra.create(values)

      assert_equal('本文です', values.dig(:program_entry, :status))
    end

    def test_empty
      assert_empty(SentryExtra.create({}))
      assert_empty(SentryExtra.create(nil))
    end

    # ⚠ 伏せ字の途中で落ちたら中身を送らない。例外も上げない。
    def test_fail_closed
      values = Object.new
      values.define_singleton_method(:blank?) {false}
      values.define_singleton_method(:to_h) {raise 'broken'}

      assert_equal({scrub_failed: true}, SentryExtra.create(values))
    end

    # alert の values が Sentry へ届く（従来は syslog にしか出なかった）。
    def test_alert_passes_extra_to_sentry
      captured = []
      stub_singleton(Sentry, :initialized?) {true}
      stub_singleton(Sentry, :capture_exception) {|error, **options| captured.push([error, options])}
      stub_singleton(Event, :new) {|*| NullEvent.new}
      error = Ginseng::GatewayError.new('tagging dictionary fetch returned nothing')
      error.alert(sources: 3, status: '本文です')

      assert_equal(1, captured.size)
      assert_same(error, captured.first.first)
      assert_equal(3, captured.first.last.dig(:extra, :sources))
      assert_equal('[FILTERED]', captured.first.last.dig(:extra, :status))
    ensure
      restore_singletons
    end

    class NullEvent
      def dispatch(_error) = nil
    end

    private

    def stub_singleton(target, name, &)
      @stubs ||= []
      original = target.method(name)
      @stubs.push([target, name, original])
      target.define_singleton_method(name, &)
    end

    def restore_singletons
      # ⚠ 元が継承したメソッド（`Event.new` の `Class#new`）なら、特異メソッドを消すだけにする。
      @stubs.to_a.reverse_each do |target, name, original|
        if original.owner == target.singleton_class
          target.define_singleton_method(name, original)
        else
          target.singleton_class.send(:remove_method, name)
        end
      end
      @stubs = []
    end
  end
end
