module Mulukhiya
  class DropboxAnnounceHandler < AnnounceHandler
    def disable?
      return false unless sns.account.dropbox
      return super
    end

    def announce(announcement, params = {})
      params = params.clone
      params[:format] = :md
      response = sns.account.dropbox.clip(body: create_body(announcement, params))
      result.push(path: response.path_display)
      return announcement
    end
  end
end
