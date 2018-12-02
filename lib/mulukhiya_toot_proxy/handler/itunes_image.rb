module MulukhiyaTootProxy
  class ItunesImageHandler < ImageHandler
    def updatable?(link)
      uri = ItunesURI.parse(link)
      return false unless uri.itunes?
      return false unless uri.track_id.present?
      return false unless uri.image_uri.present?
      return true
    end

    def create_image_container(link)
      return ItunesURI.parse(link)
    end
  end
end
