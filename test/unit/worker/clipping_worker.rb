module Mulukhiya
  class ClippingWorkerTest < TestCase
    def disable?
      return true unless test_token
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:clipping)
    end

    def test_create_body
      body = @worker.create_body(uri: 'https://precure.ml/web/statuses/107640049077500578')

      assert_equal(%{## アカウント\n[MAKOTO](https://precure.ml/@makoto)\n## 本文\nおはよう！みんな、元気してるかな？剣崎真琴です。\n昨日は、前髪を切りに行きました！さっぱり。\n[\\#precure_fun](https://precure.ml/tags/precure_fun) [\\#剣崎真琴](https://precure.ml/tags/%E5%89%A3%E5%B4%8E%E7%9C%9F%E7%90%B4) [\\#キュアソード](https://precure.ml/tags/%E3%82%AD%E3%83%A5%E3%82%A2%E3%82%BD%E3%83%BC%E3%83%89) [\\#宮本佳那子](https://precure.ml/tags/%E5%AE%AE%E6%9C%AC%E4%BD%B3%E9%82%A3%E5%AD%90) [\\#おはよう](https://precure.ml/tags/%E3%81%8A%E3%81%AF%E3%82%88%E3%81%86)\n## URL\nhttps://precure.ml/web/statuses/107640049077500578\n}, body)

      body = @worker.create_body(uri: 'https://mk.precure.fun/notes/9mgocjrsi2')

      assert_equal(%{## アカウント\n[「勇気の刃」キュアソードラブリンクBot](https://mk.precure.fun/@cureswordlovelinkbot)\n## 本文\nhttps://www.youtube.com/watch?v=s5MlMmXB_nA\n現在の再生回数は183,148回\n(あと9,816,852回)\n\n[\\#precure_fun](https://mk.precure.fun/tags/precure_fun) [\\#youtube_com](https://mk.precure.fun/tags/youtube_com) [\\#YouTube](https://mk.precure.fun/tags/YouTube) [\\#キュアソード](https://mk.precure.fun/tags/キュアソード) [\\#剣崎真琴](https://mk.precure.fun/tags/剣崎真琴) [\\#宮本佳那子](https://mk.precure.fun/tags/宮本佳那子) [\\#キュアソード_ラブリンク動画_1000万再生カウントダウン](https://mk.precure.fun/tags/キュアソード_ラブリンク動画_1000万再生カウントダウン)\n## URL\nhttps://mk.precure.fun/notes/9mgocjrsi2\n}, body)
    end
  end
end
