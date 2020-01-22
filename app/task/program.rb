namespace :mulukhiya do
  namespace :program do
    desc 'update program list'
    task :update do
      Mulukhiya::ProgramUpdateWorker.perform_async
    end
  end
end
