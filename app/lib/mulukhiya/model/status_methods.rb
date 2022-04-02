module Mulukhiya
  module StatusMethods
    def public?
      return visibility == controller_class.visibility_name(:public)
    end

    def taggable?
      return false unless public?
      return true
    end
  end
end
