module Mulukhiya
  class ClippingWorkerTest < TestCase
    def setup
      @worker = ClippingWorker.new
    end

    def test_create_body
      body = @worker.create_body(uri: 'https://precure.ml/web/statuses/107640049077500578')
      assert_equal(%{## アカウント\n[MAKOTO](https://precure.ml/@makoto)\n## 本文\nおはよう！みんな、元気してるかな？剣崎真琴です。\n昨日は、前髪を切りに行きました！さっぱり。\n[\\#precure_fun](https://precure.ml/tags/precure_fun) [\\#剣崎真琴](https://precure.ml/tags/%E5%89%A3%E5%B4%8E%E7%9C%9F%E7%90%B4) [\\#キュアソード](https://precure.ml/tags/%E3%82%AD%E3%83%A5%E3%82%A2%E3%82%BD%E3%83%BC%E3%83%89) [\\#宮本佳那子](https://precure.ml/tags/%E5%AE%AE%E6%9C%AC%E4%BD%B3%E9%82%A3%E5%AD%90) [\\#おはよう](https://precure.ml/tags/%E3%81%8A%E3%81%AF%E3%82%88%E3%81%86)\n## URL\nhttps://precure.ml/web/statuses/107640049077500578\n}, body)

      body = @worker.create_body(uri: 'https://reco.shrieker.net/notes/717e62de79253de298f3d820')
      assert_equal(%{## アカウント\n[ぷーざの録画状況ボット :pooza:](https://reco.shrieker.net/@pooza_recorder_bot)\n## 本文\n題名: 北斗の拳　第３４話「トキよ！お前は天使なのか悪魔なのか！！」\n開始: 01/16 21:30\n終了: 01/16 22:00\n概要: 原作は「週刊少年ジャンプ」に連載されて人気を集めていた武論尊、原哲夫の同名漫画。\n[\\#Reco](https://reco.shrieker.net/tags/Reco) [\\#録画開始](https://reco.shrieker.net/tags/録画開始)\n## URL\nhttps://reco.shrieker.net/notes/717e62de79253de298f3d820\n}, body)
    end
  end
end
