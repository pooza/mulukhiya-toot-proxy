module Mulukhiya
  module StatusMethods
    def visible?
      return visibility == 'public'
    end
  end
end
