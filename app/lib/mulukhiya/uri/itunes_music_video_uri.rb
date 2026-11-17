module Mulukhiya
  # Apple Music の MV の URL（`/music-video/<曲名>/<id>`）(#4897)。
  #
  # ⚠ 短縮した形（`/jp/music-video/<id>`）は、曲名の付いた正規の URL へ 301 で飛ぶ（2026-11-10 実測）。
  # ⚠ 短縮ではクエリも落とす（`ItunesSongURI` も同じ）。`uo=4` は参照元の印で、アルバムの中の曲を指す `i=` のような
  # 中身を持つ値が無いため。
  class ItunesMusicVideoURI < ItunesURI
    def valid?
      return false unless itunes?
      return false unless music_video?
      return true
    end

    def id
      return music_video_id
    end

    def shorten
      return self unless shortenable?
      dest = clone
      dest.host = config['/service/itunes/hosts'].first
      dest.music_video_id = music_video_id
      return dest
    end

    def track
      return nil unless valid?
      @track ||= @service.lookup(music_video_id)
      return @track
    end

    def album_name
      return track&.dig('collectionName')
    end

    def music_video?
      return music_video_id.present?
    end

    def music_video_id
      return nil unless matches = path.match(ItunesURI.pattern(:music_video))
      return matches[1].to_i
    end

    def music_video_id=(id)
      self.path = "/#{config['/service/itunes/country']}/music-video/#{id}"
      self.query = nil
      self.fragment = nil
    end
  end
end
