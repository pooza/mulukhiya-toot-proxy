module Mulukhiya
  class MediaFileTest < TestCase
    def test_all
      assert_kind_of(Enumerator, MediaFile.all)
      MediaFile.all do |f|
        assert(File.exist?(f))
      end
    end

    def test_purge
      MediaFile.purge
    end
  end
end