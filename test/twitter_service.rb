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
      @config['/twitter/status/default_tags'] = ['キュアスタ']

      status = @service.create_status('status' => 'hoge', 'spoiler_text' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "hoge\nhttps://precure.ml/hogefuga\n#キュアスタ")
      assert(status.valid?)

      status = @service.create_status('status' => 'hoge', 'spoiler_text' => 'ふがふが', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "ふがふが\nhttps://precure.ml/hogefuga\n#キュアスタ")
      assert(status.valid?)

      status = @service.create_status('status' => '#キュアスタ！ hoge', 'spoiler_text' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#キュアスタ！ hoge\nhttps://precure.ml/hogefuga")
      assert(status.valid?)

      status = @service.create_status('status' => 'あ' * 120, 'spoiler_text' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#{'あ' * 120}\nhttps://precure.ml/hogefuga\n#キュアスタ")
      assert(status.valid?)

      status = @service.create_status('status' => 'あ' * 121, 'spoiler_text' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#{'あ' * 120}…\nhttps://precure.ml/hogefuga\n#キュアスタ")
      assert(status.valid?)

      @config['/twitter/status/default_tags'] = []

      status = @service.create_status('status' => 'hoge', 'spoiler_text' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "hoge\nhttps://precure.ml/hogefuga")
      assert(status.valid?)

      status = @service.create_status('status' => 'あ' * 127, 'spoiler_text' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#{'あ' * 127}\nhttps://precure.ml/hogefuga")
      assert(status.valid?)

      status = @service.create_status('status' => 'あ' * 128, 'spoiler_text' => '', 'url' => 'https://precure.ml/hogefuga')
      assert_equal(status, "#{'あ' * 127}…\nhttps://precure.ml/hogefuga")
      assert(status.valid?)
    end
  end
end
