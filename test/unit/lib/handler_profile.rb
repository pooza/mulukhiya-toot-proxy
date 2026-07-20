module Mulukhiya
  class HandlerProfileTest < TestCase
    def teardown
      Thread.current[HandlerProfile::HTTP_KEY] = nil
    end

    test '既定では無効' do
      assert_false(HandlerProfile.enable?)
      assert_nil(HandlerProfile.create(Event.new(:pre_toot)))
    end

    test '閾値と floor が設定から読める' do
      assert_kind_of(Float, HandlerProfile.threshold)
      assert_kind_of(Float, HandlerProfile.floor)
      assert_true(HandlerProfile.threshold.positive?)
    end

    test 'record_http は集計先が無ければ何もしない' do
      Thread.current[HandlerProfile::HTTP_KEY] = nil
      assert_nothing_raised do
        HandlerProfile.record_http(0.5)
      end
    end

    test 'record_http がスレッドローカルへ積算される' do
      counter = {count: 0, seconds: 0.0}
      Thread.current[HandlerProfile::HTTP_KEY] = counter
      HandlerProfile.record_http(0.25)
      HandlerProfile.record_http(0.5)

      assert_equal(2, counter[:count])
      assert_in_delta(0.75, counter[:seconds], 0.001)
    end

    test 'HTTP の集計はハンドラのスレッドごとに分離される' do
      counters = Array.new(2) {{count: 0, seconds: 0.0}}
      counters.each_with_index do |counter, i|
        Thread.new do
          Thread.current[HandlerProfile::HTTP_KEY] = counter
          (i + 1).times {HandlerProfile.record_http(0.1)}
        end.join
      end

      assert_equal(1, counters[0][:count])
      assert_equal(2, counters[1][:count])
    end

    # Handler.create は SNSService 経由で DB を要求するため、record が実際に使う
    # インタフェース（underscore）だけを備えたダブルで代替する。
    HandlerDouble = Struct.new(:underscore)

    test 'record がハンドラ単位のエントリを作る' do
      profile = HandlerProfile.new(Event.new(:pre_toot))
      handler = HandlerDouble.new('default_tag')
      counter = {count: 3, seconds: 1.5}
      profile.record(handler, HandlerProfile.clock - 2, counter)
      entry = profile.entries.first

      assert_equal('default_tag', entry[:handler])
      assert_equal(3, entry[:http_count])
      assert_in_delta(1.5, entry[:http_seconds], 0.001)
      assert_true(entry[:seconds] >= 2)
    end

    test 'payload_shape はトゥートの種類を分類する' do
      shape = HandlerProfile.payload_shape({
        'status' => '#nowplaying 曲名 https://example.com/a https://example.com/b',
        'media_ids' => ['1', '2'],
      })

      assert_equal(2, shape[:urls])
      assert_equal(2, shape[:attachments])
      assert_true(shape[:nowplaying])
      assert_true(shape[:chars].positive?)
    end

    test 'payload_shape は本文そのものを含まない' do
      shape = HandlerProfile.payload_shape({'status' => '秘密の本文'})

      assert_false(shape.values.any? {|v| v.to_s.include?('秘密')})
    end

    test 'payload_shape は Hash 以外を受けても壊れない' do
      assert_equal({}, HandlerProfile.payload_shape(nil))
      assert_equal({}, HandlerProfile.payload_shape('string'))
    end

    test 'HTTPProbe が Ginseng::HTTP に prepend されている' do
      assert_true(Ginseng::HTTP <= HandlerProfile::HTTPProbe)
    end

    test 'flush は閾値未満のイベントを記録しない' do
      profile = HandlerProfile.new(Event.new(:pre_toot))
      assert_nothing_raised do
        profile.flush({'status' => 'test'})
      end
    end
  end
end
