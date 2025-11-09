$LOAD_PATH.unshift(File.join(File.expand_path('../..', __dir__), 'app/lib'))

class MulukhiyaRequestId
  def initialize(app)
    @app = app
  end

  def call(env)
    env['HTTP_X_REQUEST_ID'] ||= SecureRandom.uuid
    status, headers, body = @app.call(env)
    headers['X-Request-Id'] = env['HTTP_X_REQUEST_ID']
    [status, headers, body]
  end
end

class MulukhiyaCookieStripper
  ALLOWED = ['__Host-mastodon_session', 'mastodon_session', 'misskey_session'].freeze
  def initialize(app)
    @app = app
  end

  def call(env)
    raw = (env['HTTP_COOKIE'] || '').split(/;\s*/).select do |kv|
      name = kv.split('=', 2).first
      ALLOWED.include?(name)
    end.join('; ')
    env['mulukhiya.upstream_cookie'] = raw.empty? ? nil : raw
    @app.call(env)
  end
end

class MulukhiyaSessionBind
  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env)
    session = env['rack.session'] || {}
    ua  = (req.user_agent || '')[0, 120]
    ip  = req.ip.to_s
    ipk = ip.include?(':') ? ip.split(':').first(4).join(':') : ip.split('.').first(3).join('.')
    fp  = Digest::SHA256.hexdigest("#{ua}|#{ipk}")
    if session[:fp] && session[:fp] != fp
      session.clear
      return [401, {'Content-Type' => 'text/plain'}, ['session invalid']]
    end
    session[:fp] ||= fp
    @app.call(env)
  end
end

require 'mulukhiya'

use MulukhiyaRequestId
use MulukhiyaCookieStripper
# use MulukhiyaSessionBind # OFFで様子見

run Mulukhiya.rack
