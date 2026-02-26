module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :user_config do
      desc 'clean obsolete user config keys'
      task :clean do
        UserConfigStorage.clean
      end
    end
  end
end
