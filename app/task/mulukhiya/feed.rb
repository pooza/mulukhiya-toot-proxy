module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :feed do
      desc 'update custom feeds'
      task :update do
        FeedUpdateWorker.perform_async
      end

      CustomFeed.all do |feed|
        namespace feed.id do
          desc "#{feed.fullpath} : exec source command"
          task :exec do
            puts feed.command.to_s
            feed.command.exec_system
          end

          desc "#{feed.fullpath} : bundle install"
          task :bundler do
            feed.command.bundle_install
          end
        end
      end

      desc 'all custom feed : bundle install'
      multitask bundler: CustomFeed.all.map(&:id).map {|v| "#{v}:bundler"}
    end
  end
end
