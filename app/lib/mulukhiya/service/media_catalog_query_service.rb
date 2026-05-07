module Mulukhiya
  class MediaCatalogQueryService
    include Package

    def initialize(attachment_class: Environment.attachment_class)
      @attachment_class = attachment_class
    end

    def call(params)
      return @attachment_class.catalog(normalize(params))
    end

    private

    def normalize(params)
      params = params.dup
      params[:page] = (params[:page] || 1).to_i unless params[:cursor]
      params[:only_person] = (params[:only_person] || 0).to_i.zero? ? 0 : 1
      if params[:q].to_s.empty?
        params.delete(:q)
      else
        params[:rule] = SearchRule.new(params[:q])
      end
      return params
    end
  end
end
