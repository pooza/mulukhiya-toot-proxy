desc 'test all'
task :test do
  require 'pp'
  Mulukhiya::TestCase.load
end
