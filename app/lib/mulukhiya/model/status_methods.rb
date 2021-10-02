module Mulukhiya
  module StatusMethods
    def visible?
      return visibility == controller_class.visibility_name(:public)
    end
  end
end
