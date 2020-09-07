module Mulukhiya
  class TwitterServiceTest < TestCase
    def setup
      @service = Environment.test_account.twitter if TwitterService.config?
      @config = Config.instance
    end

    def test_config?
      assert_boolean(TwitterService.config?)
    end

    def test_tweet
      return unless TwitterService.config?
      assert_kind_of(Twitter::Tweet, @service.tweet('宇宙の闇社会を牛耳る、宇宙マフィア。'))
    end

    def test_create_status
      @config['/twitter/status/hot_words'] = ['実況']
      @config['/twitter/status/tags'] = ['キュアスタ']

      status = @service.create_status('status' => 'hoge', 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "hoge\nhttps://precure.ml/hogefuga\n#キュアスタ")
      assert(status.valid?)

      status = @service.create_status('status' => 'あ' * 120, 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#{'あ' * 120}\nhttps://precure.ml/hogefuga\n#キュアスタ")
      assert(status.valid?)

      status = @service.create_status('status' => 'あ' * 121, 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#{'あ' * 120}…\nhttps://precure.ml/hogefuga\n#キュアスタ")
      assert(status.valid?)

      status = @service.create_status('status' => "実況中だ#{'あ' * 200}", 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "実況中だ#{'あ' * 113}…\nhttps://precure.ml/hogefuga\n#キュアスタ #実況")
      assert(status.valid?)

      status = @service.create_status('status' => "#実況 #{'あ' * 200}", 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#実況 #{'あ' * 117}…\nhttps://precure.ml/hogefuga\n#キュアスタ")
      assert(status.valid?)

      @config['/twitter/status/hot_words'] = []
      @config['/twitter/status/tags'] = []

      status = @service.create_status('status' => 'hoge', 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "hoge\nhttps://precure.ml/hogefuga")
      assert(status.valid?)

      status = @service.create_status('status' => 'あ' * 127, 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#{'あ' * 127}\nhttps://precure.ml/hogefuga")
      assert(status.valid?)

      status = @service.create_status('status' => 'あ' * 128, 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#{'あ' * 127}…\nhttps://precure.ml/hogefuga")
      assert(status.valid?)

      status = @service.create_status('status' => "実況中だ#{'あ' * 200}", 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "実況中だ#{'あ' * 123}…\nhttps://precure.ml/hogefuga")
      assert(status.valid?)

      status = @service.create_status('status' => "#実況 #{'あ' * 200}", 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#実況 #{'あ' * 124}…\nhttps://precure.ml/hogefuga")
      assert(status.valid?)

      @config['/twitter/status/tags'] = ['実況']

      status = @service.create_status('status' => "実況中だ#{'あ' * 200}", 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "実況中だ#{'あ' * 119}…\nhttps://precure.ml/hogefuga\n#実況")
      assert(status.valid?)

      status = @service.create_status('status' => "#実況 #{'あ' * 200}", 'spoiler_test' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#実況 #{'あ' * 124}…\nhttps://precure.ml/hogefuga")
      assert(status.valid?)
    end
  end
end
