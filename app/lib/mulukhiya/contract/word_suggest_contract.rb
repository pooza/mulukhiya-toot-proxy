module Mulukhiya
  class WordSuggestContract < Contract
    params do
      required(:q).value(:string)
      # limit はあえて型を付けない。query string 由来で配列 (limit[]=1) 等の不正値も
      # 届くが、ここで型検証して 400 にせず PronunciationDictionary#clamp_limit が
      # 非スカラー・非正値を既定値へ倒す方針 (#4397)。型を付けると clamp の防御が
      # 殺され、公開エンドポイントが malformed limit で 400 を返すようになる。
      optional(:limit)
    end
  end
end
