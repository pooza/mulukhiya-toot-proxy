module Mulukhiya
  # タグ抽出の入口が UTF-8 を保証しているか (#4642)。
  #
  # ⚠⚠ **DB を要求しない位置に置くこと。** 隣の TagContainerTest は
  # `Environment.dbms_class&.config?` で丸ごと omit されるので、そちらに書くと
  # 「書いたのに一度も走っていない」状態になる (#4632 で踏んだカバレッジの穴)。
  # 不正バイト列は `normalize` へ届く前に弾かれるため、DB 無しで検証できる。
  class TagContainerEncodingTest < TestCase
    # "\xE3\x81" は 3 バイト文字の途中で切れた列。
    INVALID = "#\xE3\x81ほげ".dup.force_encoding(Encoding::UTF_8).freeze

    def test_invalid_byte_sequence_is_rejected_by_scan
      assert_false(INVALID.valid_encoding?)
      assert_raise(Ginseng::ValidateError) {TagContainer.scan(INVALID)}
    end

    # `initialize` が `super` へ渡す前に `sub` を掛けており、`sub` は不正バイト列で
    # `ArgumentError` を上げるため、基底の `add` の検査へ届く前に落ちていた。
    def test_invalid_byte_sequence_is_rejected_by_new
      assert_raise(Ginseng::ValidateError) {TagContainer.new([INVALID])}
    end

    # ⚠ **これが #4642 そのもの。** 基底 (ginseng-fediverse 1.8.30 以降) の
    # `self.scan` は入口で `to_utf8` を通すが、こちらが上書きすると
    # **タグ抽出の主経路が丸ごとガードを迂回する**。上書きが復活したら落とす。
    def test_scan_is_not_overridden
      assert_false(TagContainer.singleton_class.method_defined?(:scan, false))
    end

    # 寄せられるものは寄せる。scrub で黙って直すのとは別物で、
    # 化けたタグが投稿されないことが要件。
    def test_convertible_encoding_is_converted
      assert_equal('#プリキュア', TagContainer.to_utf8('#プリキュア'.encode('Windows-31J')))
    end
  end
end
