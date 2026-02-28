require 'webmock/test_unit'

module Mulukhiya
  class MultiFieldRemoteDictionaryTest < TestCase
    def setup
      WebMock.disable_net_connect!
      stub_request(:get, 'https://api.github.com/users/pooza/repos')
        .to_return(status: 200, body: fixture('github_repos_pooza.json'), headers: {'Content-Type' => 'application/json'})
      @dic = RemoteDictionary.create(
        'url' => 'https://api.github.com/users/pooza/repos',
        'fields' => ['name'],
      )
    end

    def teardown
      WebMock.reset!
      WebMock.allow_net_connect!
    end

    def test_create
      assert_kind_of(MultiFieldRemoteDictionary, @dic)
    end

    def test_parse
      result = @dic.parse

      assert_kind_of(Hash, result)
      assert_equal({pattern: /ginseng.? ?core/, regexp: 'ginseng.? ?core', words: ['ginseng-core']}, result['ginseng-core'])
    end
  end
end
