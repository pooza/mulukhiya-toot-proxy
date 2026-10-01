module Mulukhiya
  # `AnnictService#episodes` の `untitled:` (#4771・PR #4776 の Codex P2)。
  #
  # ⚠ 既定はサブタイトルの無い回を落とす。「話数 ＋」は回の有無で断るかを決めるので、
  # 落とすと「登録済みだがサブタイトルが無い」が「Annict に無い」に化ける。
  #
  # ⚠ AnnictServiceTest には置かない。あちらは本物の Annict が要り、多くの環境で
  # omit される。ここは `query` を差し替えるだけなので、どの環境でも走る。
  class AnnictUntitledEpisodesTest < TestCase
    NODES = [{
      'annictId' => 42,
      'title' => '作品',
      'episodes' => {'nodes' => [{'annictId' => 123, 'numberText' => '第5話', 'title' => nil}]},
    }].freeze

    def setup
      @service = AnnictService.allocate
      nodes = NODES
      @service.define_singleton_method(:query) do |*|
        next {'data' => {'searchWorks' => {'nodes' => nodes}}}
      end
    end

    def test_drops_untitled_episodes_by_default
      assert_empty(@service.episodes([42]))
    end

    def test_keeps_untitled_episodes_on_request
      episodes = @service.episodes([42], untitled: true)

      assert_equal(1, episodes.size)
      assert_equal(123, episodes.first['annictId'])
      assert_equal(42, episodes.first['work_annict_id'])
    end
  end
end
