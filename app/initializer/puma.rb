$LOAD_PATH.unshift(File.join(dir = File.expand_path('../..', __dir__), 'app/lib'))
ENV['RAKE'] = nil

require 'mulukhiya'
config = Mulukhiya::Config.instance
environment Mulukhiya::Environment.type
port config['/puma/port']
pidfile File.join(dir, config['/puma/pidfile'])
rackup File.join(dir, config['/puma/rackup'])
