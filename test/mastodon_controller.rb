module Mulukhiya
  class MastodonControllerTest < TestCase
    include ::Rack::Test::Methods

    def setup
      @parser = TootParser.new
      @parser.account = Environment.test_account
    end

    def app
      return MastodonController
    end

    def test_search
      header 'Authorization', "Bearer #{@parser.account.token}"
      get '/api/v2/search?q=hoge'
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@parser.account.token}"
      get '/api/v1/search?q=hoge'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)
    end

    def test_toot_length
      header 'Authorization', "Bearer #{@parser.account.token}"
      post '/api/v1/statuses', {status_field => 'A' * @parser.max_length}
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@parser.account.token}"
      post '/api/v1/statuses', {status_field => 'B' * (@parser.max_length + 1)}
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)

      header 'Authorization', "Bearer #{@parser.account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => 'C' * @parser.max_length}.to_json
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@parser.account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => 'D' * (@parser.max_length + 1)}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)
    end

    def test_toot_zenkaku
      header 'Authorization', "Bearer #{@parser.account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => '！!！!！'}.to_json
      assert(JSON.parse(last_response.body)['content'].include?('<p>！!！!！<'))
    end

    def test_toot_response
      return if Handler.create('itunes_url_nowplaying').disable?
      header 'Authorization', "Bearer #{@parser.account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => '#nowplaying https://music.apple.com/jp/album//1447931442?i=1447931444&uo=4 #日本語のタグ', 'visibility' => 'private'}.to_json
      assert(last_response.ok?)
      tags = JSON.parse(last_response.body)['tags'].map {|v| v['name']}
      assert(tags.member?('日本語のタグ'))
      assert(tags.member?('nowplaying'))

      header 'Authorization', "Bearer #{@parser.account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => "ああああ\n\nいいい\n\n#nowplaying https://music.apple.com/jp/album/1447931442?i=1447931444&uo=4\n\n#nowplaying https://music.apple.com/jp/album/405905341?i=405905342&uo=4", 'visibility' => 'private'}.to_json
      assert(last_response.ok?)
      assert_equal(JSON.parse(last_response.body)['content'], '<p>ああああ</p><p>いいい</p><p><a href="https://st.mstdn.b-shock.org/tags/nowplaying" class="mention hashtag" rel="tag">#<span>nowplaying</span></a> <a href="https://music.apple.com/jp/album/1447931442?i=1447931444&amp;uo=4" rel="nofollow noopener noreferrer" target="_blank"><span class="invisible">https://</span><span class="ellipsis">music.apple.com/jp/album/14479</span><span class="invisible">31442?i=1447931444&amp;uo=4</span></a><br />DANZEN!ふたりはプリキュア ~唯一無二の光たち~<br />五條真由美, うちやえゆか・宮本佳那子</p><p><a href="https://st.mstdn.b-shock.org/tags/nowplaying" class="mention hashtag" rel="tag">#<span>nowplaying</span></a> <a href="https://music.apple.com/jp/album/405905341?i=405905342&amp;uo=4" rel="nofollow noopener noreferrer" target="_blank"><span class="invisible">https://</span><span class="ellipsis">music.apple.com/jp/album/40590</span><span class="invisible">5341?i=405905342&amp;uo=4</span></a><br />ガンバランスdeダンス ~夢みる奇跡たち~<br />宮本佳那子</p>')
    end

    def test_webhook_entries
      return unless webhook = app.webhook_entries&.first
      assert_kind_of(String, webhook[:digest])
      assert_kind_of(String, webhook[:token])
      assert_kind_of(Environment.account_class, webhook[:account])
    end
  end
end
