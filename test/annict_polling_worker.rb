module Mulukhiya
  class AnnictPollingWorkerTest < TestCase
    def setup
      @worker = AnnictPollingWorker.new
    end

    def test_accounts
      @worker.accounts do |account|
        assert_kind_of(Environment.account_class, account)
      end
    end

    def test_create_body
      record = {
        work: {id: 111, title: 'すごいあにめ'},
        episode: {id: 111, number_text: '第24回', title: '良回'},
        record: {comment: ''},
      }
      assert_equal(@worker.create_body(record), {
        'attachments' => [],
        'text' => "すごいあにめ\n第24回「良回」を視聴。\nhttps://annict.jp/works/111/episodes/111\n",
      })

      record = {
        work: {id: 111, title: 'すごいあにめ', images: {recommended_url: 'https://image.example.com/thumbnail.png'}},
        episode: {id: 112, number_text: '第25回', title: '神回'},
        record: {comment: "すごい！\nすごいアニメの神回だった！"},
      }
      assert_equal(@worker.create_body(record), {
        'attachments' => [{'image_url' => 'https://image.example.com/thumbnail.png'}],
        'text' => "すごいあにめ\n第25回「神回」を視聴。\n\nすごい！\nすごいアニメの神回だった！\nhttps://annict.jp/works/111/episodes/112\n",
      })

      record = {
        work: {id: 111, title: 'すごいあにめ'},
        episode: {id: 113, number_text: 'EXTRA EPISODE'},
        record: {comment: "楽しい！\nすごいアニメのおまけ回だった！"},
      }
      assert_equal(@worker.create_body(record), {
        'attachments' => [],
        'text' => "すごいあにめ\nEXTRA EPISODEを視聴。\n\n楽しい！\nすごいアニメのおまけ回だった！\nhttps://annict.jp/works/111/episodes/113\n",
      })

      record = {
        work: {id: 111, title: 'すごいあにめ'},
        episode: {id: 114, title: '何話とか特に決まってない回'},
        record: {comment: "楽しい！\nすごいアニメの何話とか特に決まってない回だった！"},
      }
      assert_equal(@worker.create_body(record), {
        'attachments' => [],
        'text' => "すごいあにめ\n「何話とか特に決まってない回」を視聴。\n\n楽しい！\nすごいアニメの何話とか特に決まってない回だった！\nhttps://annict.jp/works/111/episodes/114\n",
      })
    end
  end
end
