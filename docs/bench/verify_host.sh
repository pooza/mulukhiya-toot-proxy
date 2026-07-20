#!/bin/sh
# Linode ホストの当たり外れを判定する (pooza/chubo2#68)
#
# gomander は 2026-07-20 時点で「遅い物理ホストに着地した個体」と特定されている。
# 作り直し後にこれを流し、別ホストへ移れたか・速度が出ているかを機械的に判定する。
#
#   docs/bench/verify_host.sh [host]        # 既定 gomander.b-shock.co.jp
#
# 判定基準:
#   1. host_uuid が既知の遅いホスト (KNOWN_BAD_HOST) と違うこと
#   2. チャンクベンチの min が THRESHOLD_MS 未満であること
#      （2026-07-20 実測: zugoga 14.22 / lbock 15.11 / gomander 20.05 ms）
#
# min を見るのは、最小値が「誰にも邪魔されない最良ケース」だから。
# ここが遅ければ隣人輻輳ではなくホストの素の速度が遅い。
set -u

HOST="${1:-gomander.b-shock.co.jp}"
KNOWN_BAD_HOST='a6f7baf248a8c508184174f3e75b5c1a30b551ae'
THRESHOLD_MS='15.0'
SRC="$(dirname "$0")/chunk_bench.c"

[ -f "$SRC" ] || { echo "chunk_bench.c が見つかりません: $SRC" >&2; exit 2; }

echo "=== $HOST"

meta=$(ssh -o ConnectTimeout=10 "pooza@$HOST" '
  T=$(curl -s -m 5 -X PUT http://169.254.169.254/v1/token \
        -H "Metadata-Token-Expiry-Seconds: 120" 2>/dev/null)
  [ -n "$T" ] && curl -s -m 5 http://169.254.169.254/v1/instance -H "Metadata-Token: $T" 2>/dev/null
') || { echo "SSH 失敗" >&2; exit 2; }

uuid=$(echo "$meta" | sed -n 's/^host_uuid: //p')
type=$(echo "$meta" | sed -n 's/^type: //p')
region=$(echo "$meta" | sed -n 's/^region: //p')
echo "  plan      : ${type:-?} / ${region:-?}"
echo "  host_uuid : ${uuid:-取得できず}"

bench=$(ssh -o ConnectTimeout=10 "pooza@$HOST" \
  'cat > /tmp/chunk.c && cc -O2 -o /tmp/chunk /tmp/chunk.c && /tmp/chunk' < "$SRC") \
  || { echo "ベンチ実行に失敗" >&2; exit 2; }
echo "  $bench"

min=$(echo "$bench" | sed -n 's/^min *\([0-9.]*\).*/\1/p')

fail=0
if [ -z "$uuid" ]; then
  echo "  ⚠ host_uuid を取得できず、ホスト変更を確認できません"
  fail=1
elif [ "$uuid" = "$KNOWN_BAD_HOST" ]; then
  echo "  ✗ 既知の遅いホストのままです"
  fail=1
else
  echo "  ✓ 既知の遅いホストとは別のホストです"
fi

if [ -z "$min" ]; then
  echo "  ⚠ min を取得できませんでした"
  fail=1
elif awk "BEGIN{exit !($min < $THRESHOLD_MS)}"; then
  echo "  ✓ min ${min}ms < ${THRESHOLD_MS}ms"
else
  echo "  ✗ min ${min}ms >= ${THRESHOLD_MS}ms（同じ質のホストに着地しています）"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "  → 合格。この個体で進めてよい"
  exit 0
fi
echo "  → 不合格。もう一度作り直して別ホストへの着地を狙う"
exit 1
