namespace :mulukhiya do
  namespace :media do
    desc 'clean media cache'
    task :clean do
      Mulukhiya::MediaFile.purge(console: true)
    end

    task clear: [:clean]
  end
end
