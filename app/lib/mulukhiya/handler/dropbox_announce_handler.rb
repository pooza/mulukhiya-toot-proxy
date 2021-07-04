module Mulukhiya
  class DropboxAnnounceHandler < AnnounceHandler
    def disable?
      return true unless sns.account.dropbox
      return super
    end

    def announce(params = {})
      params[:format] = :md
      response = sns.account.dropbox.clip(body: create_body(params))
      result.push(path: response.path_display)
    end
  end
end
