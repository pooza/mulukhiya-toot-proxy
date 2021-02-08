module Mulukhiya
  class AnnictServiceTest < TestCase
    def setup
      @service = account.annict if AnnictService.config?
    end

    def test_config?
      assert_boolean(AnnictService.config?)
    end

    def test_account
      return unless @service
      assert_kind_of(Hash, @service.account)
      assert_kind_of(Integer, @service.account['id'])
      assert_kind_of(String, @service.account['name'])
      assert_kind_of(String, @service.account['username'])
    end

    def test_records
      return unless @service
      assert_kind_of(Enumerator, @service.records)
      @service.records do |record|
        assert_kind_of(Hash, record)
        assert_kind_of(String, record['work']['title'])
        assert_kind_of([Float, NilClass], record['episode']['number'])
        uri = Ginseng::URI.parse(record.dig('work', 'images', 'recomended_url'))
        assert(uri.absolute?) if uri
      end
    end

    def test_recent_records
      return unless @service
      assert_kind_of(Enumerator, @service.recent_records)
    end

    def test_reviewed_works
      return unless @service
      assert_kind_of(Enumerator, @service.reviewed_works)
      @service.reviewed_works do |work|
        assert_kind_of(Hash, work)
        assert_kind_of(Integer, work['work']['id'])
      end
    end

    def test_reviews
      return unless @service
      assert_kind_of(Enumerator, @service.reviews)
      @service.reviews do |review|
        assert_kind_of(Hash, review)
        assert_kind_of(String, review['work']['title'])
        uri = Ginseng::URI.parse(review.dig('work', 'images', 'recomended_url'))
        assert(uri.absolute?) if uri
      end
    end

    def test_recent_reviews
      return unless @service
      assert_kind_of(Enumerator, @service.recent_reviews)
    end

    def test_updated_at
      return unless @service
      assert_kind_of([Time, NilClass], @service.updated_at)
    end

    def test_oauth_uri
      return unless @service
      assert_kind_of(Ginseng::URI, @service.oauth_uri)
    end

    def test_create_create_payload
      return unless @service
      record = {
        work: {id: 111, title: 'すごいあにめ'},
        episode: {id: 111, number_text: '第24回', title: '良回'},
        record: {comment: ''},
      }
      assert_equal(@service.create_payload(record, :record).raw, {
        'text' => "すごいあにめ\n第24回「良回」を視聴。\nhttps://annict.jp/works/111/episodes/111\n",
      })

      record = {
        work: {id: 111, title: 'すごいあにめ', images: {recommended_url: 'https://image.example.com/thumbnail.png'}},
        episode: {id: 112, number_text: '第25回', title: '神回'},
        record: {comment: "すごい！\nすごいアニメの神回だった！"},
      }
      assert_equal(@service.create_payload(record, :record).raw, {
        'attachments' => [{'image_url' => 'https://image.example.com/thumbnail.png'}],
        'text' => "すごいあにめ\n第25回「神回」を視聴。\n\nすごい！\nすごいアニメの神回だった！\nhttps://annict.jp/works/111/episodes/112\n",
      })

      record = {
        work: {id: 111, title: 'すごいあにめ', images: {recommended_url: 'https://image.example.com/thumbnail.png'}},
        episode: {id: 112, number_text: '第25回', title: '神回'},
        record: {comment: "ネタバレ感想！すごい！\nすごいアニメの神回だった！"},
      }
      assert_equal(@service.create_payload(record, :record).raw, {
        'attachments' => [{'image_url' => 'https://image.example.com/thumbnail.png'}],
        'spoiler_text' => 'すごいあにめ 第25回「神回」を視聴。 （ネタバレ）',
        'text' => "ネタバレ感想！すごい！\nすごいアニメの神回だった！\nhttps://annict.jp/works/111/episodes/112\n",
      })

      record = {
        work: {id: 111, title: 'すごいあにめ'},
        episode: {id: 113, number_text: 'EXTRA EPISODE'},
        record: {comment: "楽しい！\nすごいアニメのおまけ回だった！"},
      }
      assert_equal(@service.create_payload(record, :record).raw, {
        'text' => "すごいあにめ\nEXTRA EPISODEを視聴。\n\n楽しい！\nすごいアニメのおまけ回だった！\nhttps://annict.jp/works/111/episodes/113\n",
      })

      record = {
        work: {id: 111, title: 'すごいあにめ'},
        episode: {id: 114, title: '何話とか特に決まってない回'},
        record: {comment: "楽しい！\nすごいアニメの何話とか特に決まってない回だった！"},
      }
      assert_equal(@service.create_payload(record, :record).raw, {
        'text' => "すごいあにめ\n「何話とか特に決まってない回」を視聴。\n\n楽しい！\nすごいアニメの何話とか特に決まってない回だった！\nhttps://annict.jp/works/111/episodes/114\n",
      })

      review = {
        work: {id: 112, title: 'すごいあにめTHE MOVIE', images: {recommended_url: 'https://image.example.com/thumbnail.png'}},
        body: "超楽しい！\nすばらしい劇場版だった！",
      }
      assert_equal(@service.create_payload(review, :review).raw, {
        'attachments' => [{'image_url' => 'https://image.example.com/thumbnail.png'}],
        'text' => "「すごいあにめTHE MOVIE」を視聴。\n\n超楽しい！\nすばらしい劇場版だった！\nhttps://annict.jp/works/112/records\n",
      })

      review = {
        work: {id: 112, title: 'すごいあにめTHE MOVIE', images: {recommended_url: 'https://image.example.com/thumbnail.png'}},
        body: "ネタバレ感想\n超楽しい！\nすばらしい劇場版だった！",
      }
      assert_equal(@service.create_payload(review, :review).raw, {
        'attachments' => [{'image_url' => 'https://image.example.com/thumbnail.png'}],
        'spoiler_text' => '「すごいあにめTHE MOVIE」を視聴。 （ネタバレ）',
        'text' => "ネタバレ感想\n超楽しい！\nすばらしい劇場版だった！\nhttps://annict.jp/works/112/records\n",
      })
    end
  end
end
