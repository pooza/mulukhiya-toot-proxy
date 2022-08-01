module Mulukhiya
  class MediaFileTest < TestCase
    def test_all
      assert_kind_of(Enumerator, MediaFile.all)
      MediaFile.all do |f|
        assert_path_exist(f)
      end
    end

    def test_create_dest_path
      assert_kind_of(Enumerator, MediaFile.all)
      MediaFile.all do |f|
        basename = File.basename(MediaFile.new(f).create_dest_path(extname: '.webp'), '.webp')
        assert_equal(64, basename.length)
      end
    end

    def test_purge
      MediaFile.purge
    end
  end
end
