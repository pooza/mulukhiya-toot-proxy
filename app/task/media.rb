namespace :mulukhiya do
  namespace :media do
    desc 'clean media cache'
    task :clean do
      MediaCleaningWorker.new.perform
    end

    task clear: [:clean]
  end
end
