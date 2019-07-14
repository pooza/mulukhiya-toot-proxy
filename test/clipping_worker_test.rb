module MulukhiyaTootProxy
  class ClippingWorkerTest < Test::Unit::TestCase
    def setup
      @worker = ClippingWorker.new
    end

    def test_create_body
      body = @worker.create_body('uri' => {
        'class' => 'MulukhiyaTootProxy::MastodonURI',
        'href' => 'https://st.mstdn.b-shock.org/web/statuses/102439289911294939',
      })
      assert_equal(body, %{## アカウント\n[@ぷーざさん ステージング](https://st.mstdn.b-shock.org/@pooza)\n\n## 本文\n 木の水晶球 \n\n## URL\nhttps://st.mstdn.b-shock.org/@pooza/102439289911294939\n})
    end
  end
end
