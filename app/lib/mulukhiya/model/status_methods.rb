module Mulukhiya
  module StatusMethods
    def public?
      return visibility == controller_class.visibility_name(:public)
    end

    alias taggable? public?
  end
end
