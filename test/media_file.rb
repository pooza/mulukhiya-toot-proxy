module Mulukhiya
  class MediaFileTest < TestCase
    def files(&block)
      return enum_for(__method__) unless block
      finder = Ginseng::FileFinder.new
      finder.dir = File.join(Environment.dir, 'public/mulukhiya/media')
      finder.patterns.push('*')
      finder.exec.select {|f| FileTest.file?(f)}.each(&block)
    end

    def test_all
      files do |f|
        assert_path_exist(f)
      end
    end

    def test_create_dest_path
      files do |f|
        basename = File.basename(MediaFile.new(f).create_dest_path(extname: '.webp'), '.webp')

        assert_equal(64, basename.length)
      end
    end

    def test_video_stream
      files.filter_map {|f| MediaFile.new(f).file}.select {|f| f.is_a?(VideoFile)}.each do |f|
        assert_kind_of(Hash, f.video_stream)
      end
    end

    def test_audio_stream
      files.filter_map {|f| MediaFile.new(f).file}.select {|f| f.is_a?(AudioFile)}.each do |f|
        assert_kind_of(Hash, f.audio_stream)
      end
    end

    def test_container
      files.filter_map {|f| MediaFile.new(f).file}.reject {|f| f.is_a?(ImageFile)}.each do |f|
        assert_kind_of(Hash, f.container)
      end
    end

    def test_purge
      MediaFile.purge
    end
  end
end
