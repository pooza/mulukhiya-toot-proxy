module Mulukhiya
  class ComposeTemplateContractTest < TestCase
    def setup
      @contract = ComposeTemplateContract.new
    end

    def test_call
      assert_empty(@contract.call(name: '実況開始', body: 'はじまるよ').errors)
      assert_empty(@contract.call(name: 'CW あり', body: '本文', cw: '注意').errors)
      # body の空文字は許容（本文だけ空のテンプレを認める）。
      assert_empty(@contract.call(name: '空本文', body: '').errors)
      # cw は任意（欠落・nil 許容）。
      assert_empty(@contract.call(name: 'x', body: 'y', cw: nil).errors)

      # name 必須・非空（空白のみも rule で弾く）。
      assert_false(@contract.call(body: 'y').errors.empty?)
      assert_false(@contract.call(name: '', body: 'y').errors.empty?)
      assert_false(@contract.call(name: '  ', body: 'y').errors.empty?)
      # body 必須。
      assert_false(@contract.call(name: 'x').errors.empty?)
      # 各上限超過。
      assert_false(@contract.call(name: 'a' * (ComposeTemplateContract::MAX_NAME_SIZE + 1), body: 'y').errors.empty?)
      assert_false(@contract.call(name: 'x', body: 'a' * (ComposeTemplateContract::MAX_BODY_SIZE + 1)).errors.empty?)
      assert_false(@contract.call(name: 'x', body: 'y', cw: 'a' * (ComposeTemplateContract::MAX_CW_SIZE + 1)).errors.empty?)
    end
  end
end
