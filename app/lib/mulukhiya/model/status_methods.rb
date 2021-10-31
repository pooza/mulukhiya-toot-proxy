module Mulukhiya
  module StatusMethods
    def public?
      return visibility == controller_class.visibility_name(:public)
    end
  end
end
