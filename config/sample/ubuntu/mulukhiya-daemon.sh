#!/bin/bash
# mulukhiya-toot-proxy daemon management script (daemon-spawn)
# Usage: mulukhiya-daemon.sh {start|stop|restart}
#
# This script manages puma/sidekiq/listener daemons directly
# via daemon-spawn, without systemd.
#
# Configuration:
#   MULUKHIYA_PATH - path to mulukhiya-toot-proxy
#   MULUKHIYA_USER - user to run daemons as (optional, for root execution)

MULUKHIYA_PATH="${MULUKHIYA_PATH:-/home/__username__/path/to/mulukhiya-toot-proxy}"
MULUKHIYA_USER="${MULUKHIYA_USER:-}"

run_cmd() {
  cd "$MULUKHIYA_PATH" || exit 1
  if [ -n "$MULUKHIYA_USER" ] && [ "$(id -u)" -eq 0 ]; then
    sudo -u "$MULUKHIYA_USER" /bin/bash -lc "$1"
  else
    /bin/bash -lc "$1"
  fi
}

case "$1" in
  start)
    run_cmd 'bundle exec rake mulukhiya:puma:start'
    run_cmd 'bundle exec rake mulukhiya:sidekiq:start'
    run_cmd 'bundle exec rake mulukhiya:listener:start'
    ;;
  stop)
    run_cmd 'bundle exec rake mulukhiya:listener:stop'
    run_cmd 'bundle exec rake mulukhiya:sidekiq:stop'
    run_cmd 'bundle exec rake mulukhiya:puma:stop'
    ;;
  restart)
    "$0" stop
    "$0" start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}" >&2
    exit 1
    ;;
esac
