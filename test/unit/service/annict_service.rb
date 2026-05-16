module Mulukhiya
  class AnnictServiceTest < TestCase
    def disable?
      return true unless controller_class.annict?
      return true unless AnnictService.config?
      return true unless account.annict rescue nil
      return super
    end

    def setup
      return if disable?
      config['/service/annict/episodes/ruby/trim'] = true
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
      assert_kind_of(Ginseng::URI, @service.account[:avatar_uri]) if @service.account[:avatar_uri]
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

      works = @service.works('おジャ魔女')

      assert_kind_of(Array, works)
      works.each do |work|
        assert_kind_of(Integer, work['annictId'])
        assert_kind_of(String, work['title'])
        assert_kind_of(Integer, work['seasonYear'])
        assert_kind_of(Ginseng::URI, work['officialSiteUrl']) if work['officialSiteUrl']
      end
    end

    def test_episodes
      id = @service.works.filter_map {|v| v['annictId']}.last
      @service.episodes([id]).each do |episode|
        assert_kind_of(String, episode['numberText'])
        assert_kind_of(String, episode['title'])
        assert_kind_of(String, episode['hashtag'])
        assert_kind_of(Ginseng::URI, episode['hashtag_uri'])
        assert_kind_of(Ginseng::URI, episode['url'])
        assert_predicate(episode['url'], :absolute?)
        assert_match(%r{/works/#{id}/episodes/\d+\z}, episode['url'].to_s)
        assert_kind_of(String, episode['command_toot'])
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

    def test_create_episode_uri
      assert_equal(
        'https://annict.com/works/7879/episodes/138263',
        AnnictService.create_episode_uri(7879, 138_263).to_s,
      )
      assert_nil(AnnictService.create_episode_uri(nil, 138_263))
      assert_nil(AnnictService.create_episode_uri(7879, nil))
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

    # #4339: create_record は resolve_episode → createRecord の 2 段クエリに
    # なった。query 種別でレスポンスを出し分けるスタブを張り、捕捉した
    # リクエストボディを {resolve:, create:} で返す。
    def stub_annict_create_record(endpoint, resolve:, create:)
      captured = {}
      stub_request(:post, endpoint).with do |request|
        body = JSON.parse(request.body)
        next false unless body['query'].include?('searchEpisodes')
        captured[:resolve] = body
        true
      end.to_return(body: resolve.to_json, headers: {'Content-Type' => 'application/json'})
      stub_request(:post, endpoint).with do |request|
        body = JSON.parse(request.body)
        next false unless body['query'].include?('createRecord')
        captured[:create] = body
        true
      end.to_return(body: create.to_json, headers: {'Content-Type' => 'application/json'})
      return captured
    end

    def test_create_record_resolves_node_id_and_sends_mutation
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      node_id = 'RXBpc29kZS02MzE2Mg=='
      captured = stub_annict_create_record(
        endpoint,
        resolve: {data: {searchEpisodes: {nodes: [
          {id: 'RXBpc29kZS05OTk=', annictId: 999},
          {id: node_id, annictId: 63_162},
        ]}}},
        create: {data: {createRecord: {record: {
          id: 'gid://annict/Record/4_141_053',
          annictId: 4_141_053,
          comment: 'よかった',
          ratingState: 'GREAT',
          rating: nil,
          createdAt: '2026-05-07T12:00:00Z',
        }}}},
      )

      record = @service.create_record(episode_id: 63_162, comment: 'よかった', rating_state: 'GREAT')

      assert_equal(4_141_053, record['annictId'])
      assert_equal('GREAT', record['ratingState'])
      assert_match(/searchEpisodes/, captured.dig(:resolve, 'query'))
      assert_equal([63_162], captured.dig(:resolve, 'variables', 'annictIds'))
      assert_match(/createRecord/, captured.dig(:create, 'query'))
      assert_equal(node_id, captured.dig(:create, 'variables', 'episodeId'))
      assert_equal('よかった', captured.dig(:create, 'variables', 'comment'))
      assert_equal('GREAT', captured.dig(:create, 'variables', 'ratingState'))
    end

    def test_create_record_omits_blank_optional_variables
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      node_id = 'RXBpc29kZS0x'
      captured = stub_annict_create_record(
        endpoint,
        resolve: {data: {searchEpisodes: {nodes: [{id: node_id, annictId: 1}]}}},
        create: {data: {createRecord: {record: {annictId: 1}}}},
      )

      @service.create_record(episode_id: 1)

      assert_equal({'episodeId' => node_id}, captured.dig(:create, 'variables'))
    end

    def test_create_record_raises_not_found_when_episode_unresolved
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      stub_request(:post, endpoint).to_return(
        body: {data: {searchEpisodes: {nodes: []}}}.to_json,
        headers: {'Content-Type' => 'application/json'},
      )

      assert_raise(Ginseng::NotFoundError) do
        @service.create_record(episode_id: 20_314)
      end
    end

    def test_create_record_normalizes_scope_graphql_error_to_auth_error
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      stub_annict_create_record(
        endpoint,
        resolve: {data: {searchEpisodes: {nodes: [{id: 'RXBpc29kZS0yMDMxNA==', annictId: 20_314}]}}},
        create: {errors: [{message: 'You are not authorized: missing write scope'}]},
      )

      assert_raise(Ginseng::AuthError) do
        @service.create_record(episode_id: 20_314)
      end
    end

    def test_create_record_normalizes_http_403_to_auth_error
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      stub_request(:post, endpoint).to_return(
        status: 403,
        body: 'Forbidden',
        headers: {'Content-Type' => 'text/plain'},
      )

      assert_raise(Ginseng::AuthError) do
        @service.create_record(episode_id: 20_314)
      end
    end

    def test_create_record_raises_gateway_error_on_unclassified_graphql_errors
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      stub_request(:post, endpoint).to_return(
        body: {errors: [{message: 'Internal server error'}]}.to_json,
        headers: {'Content-Type' => 'application/json'},
      )

      assert_raise(Ginseng::GatewayError) do
        @service.create_record(episode_id: 999_999)
      end
    end

    # #4329: クライアント起因の Annict GraphQL errors を 502 に丸めず
    # 404 / 422 に分類する。
    def test_create_record_classifies_not_found_graphql_error
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      stub_request(:post, endpoint).to_return(
        body: {errors: [{message: 'Episode does not exist'}]}.to_json,
        headers: {'Content-Type' => 'application/json'},
      )

      assert_raise(Ginseng::NotFoundError) do
        @service.create_record(episode_id: 999_999)
      end
    end

    def test_create_record_classifies_validation_graphql_error_by_message
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      stub_request(:post, endpoint).to_return(
        body: {errors: [{message: 'Argument is invalid'}]}.to_json,
        headers: {'Content-Type' => 'application/json'},
      )

      assert_raise(Ginseng::ValidateError) do
        @service.create_record(episode_id: 999_999)
      end
    end

    def test_create_record_classifies_graphql_error_by_extensions_code
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      stub_request(:post, endpoint).to_return(
        body: {errors: [{message: 'boom', extensions: {code: 'NOT_FOUND'}}]}.to_json,
        headers: {'Content-Type' => 'application/json'},
      )

      assert_raise(Ginseng::NotFoundError) do
        @service.create_record(episode_id: 999_999)
      end
    end

    def test_create_record_raises_on_non_hash_response
      return if disable?
      endpoint = config['/service/annict/urls/api/graphql']
      stub_request(:post, endpoint).to_return(
        status: 200,
        body: 'maintenance: please try again later',
        headers: {'Content-Type' => 'text/plain'},
      )

      assert_raise(Ginseng::GatewayError) do
        @service.create_record(episode_id: 1)
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
        'spoiler_text' => 'すごいあにめ 第25回「神回」を視聴。（ネタバレ）',
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
        episode: {
          annictId: 114,
          title: '影(ミスト)と死神(キル)',
          work: {annictId: 111, title: 'ドラゴンクエスト ダイの大冒険'},
        },
        comment: 'ぼくの考えたシャドウバーンという幹部を本編に出演させてください。',
      }

      assert_equal({
        'text' => "ドラゴンクエスト ダイの大冒険\n「影と死神」を視聴。\n\nぼくの考えたシャドウバーンという幹部を本編に出演させてください。\nhttps://annict.com/works/111/episodes/114\n#ドラゴンクエスト_ダイの大冒険 #影と死神\n",
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
        'spoiler_text' => '「すごいあにめTHE MOVIE」を視聴。（ネタバレ）',
        'text' => "ネタバレ感想\n超楽しい！\nすばらしい劇場版だった！\nhttps://annict.com/works/112/records\n#すごいあにめTHE_MOVIE\n",
      }, @service.create_payload(review).raw)
    end
  end
end
