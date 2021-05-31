namespace :mulukhiya do
  namespace :feed do
    desc 'update custom feeds'
    task :update do
      Mulukhiya::CustomFeed.instance.update
    end
  end
end
