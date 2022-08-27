module Mulukhiya
  class AnnictServiceTest < TestCase
    def disable?
      return true unless controller_class.annict?
      return true unless AnnictService.config?
      return true unless (account.annict rescue nil)
      return super
    end

    def setup
      @service = account.annict
    end

    def test_config?
      assert_predicate(AnnictService, :config?)
    end

    def test_account
      assert_kind_of(Hash, @service.account)
      assert_predicate(@service.account[:id], :positive?)
      assert_predicate(@service.account[:name], :present?)
      assert_predicate(@service.account[:username], :present?)
      assert_kind_of(Ginseng::URI, @service.account[:avatar_uri])
    end

    def test_works
      works = @service.works
      assert_kind_of(Array, works)
      works.each do |work|
        assert_kind_of(Integer, work['annictId'])
        assert_kind_of(String, work['title'])
        assert_kind_of(Integer, work['seasonYear'])
        assert_kind_of(Ginseng::URI, work['officialSiteUrl']) if work['officialSiteUrl']
      end
    end

    def test_activities
      activities = @service.activities
      assert_kind_of(Enumerator, activities)
      activities.each do |activity|
        assert_kind_of(Hash, activity)
        assert_kind_of(Time, Time.parse(activity['createdAt']))
        case activity['__typename']
        when 'Record'
          assert_kind_of(Hash, activity['episode'])
          assert_kind_of(Hash, activity.dig('episode', 'work'))
          assert_kind_of(String, activity['comment'])
        when 'Review'
          assert_kind_of(Hash, activity['work'])
          assert_kind_of(String, activity['body'])
        end
      end
    end

    def test_updated_at
      return unless @service
      assert_kind_of([Time, NilClass], @service.updated_at)
    end

    def test_oauth_uri
      return unless @service
      assert_kind_of(Ginseng::URI, @service.oauth_uri)
      assert_predicate(@service.oauth_uri, :absolute?)
    end

    def test_oauth_scopes
      assert_kind_of(Array, AnnictService.oauth_scopes)
      assert_predicate(AnnictService.oauth_scopes, :present?)
      AnnictService.oauth_scopes.each do |scope|
        assert_kind_of(String, scope)
      end
    end

    def test_create_record_uri
      assert_equal('https://annict.com/works/7879/episodes/138263', AnnictService.create_record_uri(7879, 138_263).to_s)
    end

    def test_create_review_uri
      assert_equal('https://annict.com/works/7879/records', AnnictService.create_review_uri(7879).to_s)
    end

    def test_create_episode_number_text
      assert_nil(AnnictService.create_episode_number_text(nil))
      assert_equal('幕間回', AnnictService.create_episode_number_text('幕間回'))
      assert_equal('1話', AnnictService.create_episode_number_text('1話'))
      assert_equal('12話', AnnictService.create_episode_number_text('STAGE.12'))
      assert_equal('12.5話', AnnictService.create_episode_number_text('第12.5回'))
    end

    def test_accounts
      AnnictService.accounts.each do |account|
        assert_kind_of(account_class, account)
        assert_kind_of(AnnictService, account.annict)
      end
    end

    def test_create_payload
      return unless @service
      record = {
        __typename: 'Record',
        episode: {
          annictId: 111,
          numberText: '第24回',
          title: '良回',
          work: {annictId: 111, title: 'すごいあにめ'},
        },
        comment: '',
      }
      assert_equal({
        'text' => "すごいあにめ\n第24回「良回」を視聴。\nhttps://annict.com/works/111/episodes/111\n#すごいあにめ #24話 #良回\n",
      }, @service.create_payload(record).raw)

      record = {
        __typename: 'Record',
        episode: {
          annictId: 112,
          numberText: '第25回',
          title: '神回',
          work: {annictId: 111, title: 'すごいあにめ'},
        },
        comment: "すごい！\nすごいアニメの神回だった！",
      }
      assert_equal({
        'text' => "すごいあにめ\n第25回「神回」を視聴。\n\nすごい！\nすごいアニメの神回だった！\nhttps://annict.com/works/111/episodes/112\n#すごいあにめ #25話 #神回\n",
      }, @service.create_payload(record).raw)

      record = {
        __typename: 'Record',
        episode: {
          annictId: 112,
          numberText: '第25回',
          title: '神回',
          work: {annictId: 111, title: 'すごいあにめ'},
        },
        comment: "ネタバレ感想！すごい！\nすごいアニメの神回だった！",
      }
      assert_equal({
        'spoiler_text' => 'すごいあにめ 第25回「神回」を視聴。 （ネタバレ）',
        'text' => "ネタバレ感想！すごい！\nすごいアニメの神回だった！\nhttps://annict.com/works/111/episodes/112\n#すごいあにめ #25話 #神回\n",
      }, @service.create_payload(record).raw)

      record = {
        __typename: 'Record',
        episode: {
          annictId: 113,
          numberText: 'EXTRA EPISODE',
          work: {annictId: 111, title: 'すごいあにめ'},
        },
        comment: "楽しい！\nすごいアニメのおまけ回だった！",
      }
      assert_equal({
        'text' => "すごいあにめ\nEXTRA EPISODEを視聴。\n\n楽しい！\nすごいアニメのおまけ回だった！\nhttps://annict.com/works/111/episodes/113\n#すごいあにめ #EXTRA_EPISODE\n",
      }, @service.create_payload(record).raw)

      record = {
        __typename: 'Record',
        episode: {
          annictId: 114,
          title: '何話とか特に決まってない回',
          work: {annictId: 111, title: 'すごいあにめ'},
        },
        comment: "楽しい！\nすごいアニメの何話とか特に決まってない回だった！",
      }
      assert_equal({
        'text' => "すごいあにめ\n「何話とか特に決まってない回」を視聴。\n\n楽しい！\nすごいアニメの何話とか特に決まってない回だった！\nhttps://annict.com/works/111/episodes/114\n#すごいあにめ #何話とか特に決まってない回\n",
      }, @service.create_payload(record).raw)

      record = {
        __typename: 'Record',
        annictId: 4_141_053,
        episode: {
          annictId: 63_162,
          work: {annictId: 4274, title: 'Go！プリンセスプリキュア'},
          numberText: '第46話',
          title: '美しい…!?さすらうシャットと雪の城！',
        },
        comment: "本日の朝実況。\n戯れで雪の城を造り始めたトワの元に、たくさんの仲間が集まってきた。\n",
      }
      assert_equal({
        'text' => "Go！プリンセスプリキュア\n第46話「美しい…!?さすらうシャットと雪の城！」を視聴。\n\n本日の朝実況。\n戯れで雪の城を造り始めたトワの元に、たくさんの仲間が集まってきた。\n\nhttps://annict.com/works/4274/episodes/63162\n#Go_プリンセスプリキュア #46話 #美しい_さすらうシャットと雪の城\n",
      }, @service.create_payload(record).raw)

      review = {
        __typename: 'Review',
        work: {annictId: 112, title: 'すごいあにめTHE MOVIE'},
        body: "超楽しい！\nすばらしい劇場版だった！",
      }
      assert_equal({
        'text' => "「すごいあにめTHE MOVIE」を視聴。\n\n超楽しい！\nすばらしい劇場版だった！\nhttps://annict.com/works/112/records\n#すごいあにめTHE_MOVIE\n",
      }, @service.create_payload(review).raw)

      review = {
        __typename: 'Review',
        work: {annictId: 112, title: 'すごいあにめTHE MOVIE'},
        body: "ネタバレ感想\n超楽しい！\nすばらしい劇場版だった！",
      }
      assert_equal({
        'spoiler_text' => '「すごいあにめTHE MOVIE」を視聴。 （ネタバレ）',
        'text' => "ネタバレ感想\n超楽しい！\nすばらしい劇場版だった！\nhttps://annict.com/works/112/records\n#すごいあにめTHE_MOVIE\n",
      }, @service.create_payload(review).raw)
    end
  end
end
