module Mulukhiya
  class ClippingWorkerTest < TestCase
    def setup
      @worker = ClippingWorker.new
    end

    def test_create_body
      body = @worker.create_body(uri: 'https://precure.ml/web/statuses/107640049077500578')
      assert_equal(body, %{## アカウント\n[MAKOTO](https://precure.ml/@makoto)\n## 本文\nおはよう！みんな、元気してるかな？剣崎真琴です。\n昨日は、前髪を切りに行きました！さっぱり。\n[\\#precure_fun](https://precure.ml/tags/precure_fun) [\\#剣崎真琴](https://precure.ml/tags/%E5%89%A3%E5%B4%8E%E7%9C%9F%E7%90%B4) [\\#キュアソード](https://precure.ml/tags/%E3%82%AD%E3%83%A5%E3%82%A2%E3%82%BD%E3%83%BC%E3%83%89) [\\#宮本佳那子](https://precure.ml/tags/%E5%AE%AE%E6%9C%AC%E4%BD%B3%E9%82%A3%E5%AD%90) [\\#おはよう](https://precure.ml/tags/%E3%81%8A%E3%81%AF%E3%82%88%E3%81%86)\n## URL\nhttps://precure.ml/web/statuses/107640049077500578\n})
    end
  end
end
