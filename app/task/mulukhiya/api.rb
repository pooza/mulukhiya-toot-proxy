module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :api do
      CustomAPI.all do |api|
        namespace api.id do
          unless api.args?
            desc "#{api.fullpath} : exec source command"
            task :exec do
              puts api.create_command.to_s
              api.create_command.exec_system
            end
          end

          desc "#{api.fullpath} : bundle install"
          task :bundler do
            api.create_command.bundle_install
          end
        end
      end

      desc 'all custom API : bundle install'
      multitask bundler: CustomAPI.all.map(&:id).map {|v| "#{v}:bundler"}
    end
  end
end