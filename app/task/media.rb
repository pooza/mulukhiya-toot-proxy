namespace :mulukhiya do
  namespace :media do
    desc 'clean media cache'
    task :clean do
      Dir.glob(File.join(Mulukhiya::Environment.dir, 'tmp/media/*')).each do |path|
        File.unlink(path)
        puts "#{path} deleted"
      rescue => e
        puts "#{path} #{e.class}: #{e.messagee}"
      end
    end

    task clear: [:clean]
  end
end
