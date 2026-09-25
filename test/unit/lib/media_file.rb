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
        file = MediaFile.new(f)
        dest = file.create_dest_path(extname: '.webp')

        assert_equal('.webp', File.extname(dest))
        assert(File.basename(dest).start_with?(File.read(f).sha256))
      end
    end

    # ⚠⚠ **同じ内容の変換で出力先が重ならないこと (#4722)。**以前は内容の sha256 から
    # 決まる固定名で、同じ動画・画像がほぼ同時に 2 回上がる（連投・webhook の再送）と、
    # 片方がアップロード中のファイルをもう片方の ffmpeg (`-y`) / vips が切り詰めうる。
    # ⚠ ffmpeg は拡張子で出力形式を決めるので、拡張子は保つこと。
    def test_create_dest_path_is_unique_per_call
      files do |f|
        file = MediaFile.new(f)
        paths = Array.new(3) {file.create_dest_path(type: 'video/mp4')}

        assert_equal(3, paths.uniq.size)
        paths.each {|v| assert_equal('.mp4', File.extname(v))}
      end
    end

    def test_video_stream
      files.filter_map {|f| MediaFile.new(f).file}.grep(VideoFile).each do |f|
        assert_kind_of(Hash, f.video_stream)
      end
    end

    def test_audio_stream
      files.filter_map {|f| MediaFile.new(f).file}.grep(AudioFile).each do |f|
        assert_kind_of(Hash, f.audio_stream)
      end
    end

    def test_container
      files.filter_map {|f| MediaFile.new(f).file}.grep_v(ImageFile).each do |f|
        assert_kind_of(Hash, f.container)
      end
    end

    def test_purge
      MediaFile.purge
    end
  end
end
