module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :tagging do
      namespace :dic do
        desc 'update tagging dictionary'
        task :update do
          TaggingDictionaryUpdateWorker.perform_async
        end
      end

      namespace :user do
        desc 'show user tags'
        task :list do
          UserConfigStorage.tag_owners do |account|
            puts({
              account: account.acct.to_s,
              tags: account.user_config.tags,
            }).deep_stringify_keys.to_yaml
          end
        end

        task show: [:list]

        desc 'clear user tags'
        task :clean do
          UserConfigStorage.clear_tags
        end

        task clear: [:clean]
      end
    end
  end
end
