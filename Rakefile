dir = File.expand_path(__dir__)
$LOAD_PATH.unshift(File.join(dir, 'app/lib'))
ENV['BUNDLE_GEMFILE'] ||= File.join(dir, 'Gemfile')

require 'bundler/setup'
require 'mulukhiya'

Dir.glob(File.join(Mulukhiya::Environment.dir, 'app/task/*.rb')).sort.each do |f|
  require f
end
