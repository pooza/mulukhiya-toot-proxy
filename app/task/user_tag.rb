namespace :mulukhiya do
  namespace :tagging do
    namespace :user do
      desc 'show tags'
      task :list do
        Mulukhiya::UserConfigStorage.tag_owners do |account|
          puts({
            account: account.acct.to_s,
            tags: account.user_config.tags,
          }).deep_stringify_keys.to_yaml
        end
      end

      task show: [:list] # rubocop:disable Rake/Desc

      desc 'clear tags'
      task :clean do
        Mulukhiya::UserConfigStorage.clear_tags
      end

      task clear: [:clean] # rubocop:disable Rake/Desc
    end
  end
end
