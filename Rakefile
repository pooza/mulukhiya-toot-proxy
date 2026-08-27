$LOAD_PATH.unshift(File.join(File.expand_path(__dir__), 'app/lib'))
ENV['RAKE'] = 'yes'

require 'mulukhiya'
Mulukhiya.load_tasks
# ⚠ gem が配る cert:update / cert:check を生やす (#4617 / pooza/ginseng-core#512)。
# ⚠⚠ **自分の Environment を渡すこと**（省略すると gem のルート＝ bundler の
# チェックアウト側へ書きに行く。pooza/ginseng-core#548）。
Ginseng.load_tasks(environment: Mulukhiya::Environment)
