module Mulukhiya
  module StatusMethods
    def visible?
      return visibility == visibility_name('public')
    end
  end
end
