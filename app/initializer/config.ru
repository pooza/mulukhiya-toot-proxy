$LOAD_PATH.unshift(File.join(File.expand_path('../..', __dir__), 'app/lib'))

require 'mulukhiya'
run Mulukhiya.rack
