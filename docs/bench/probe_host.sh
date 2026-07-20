#!/bin/sh
# 作った直後の Linode（素の Linux イメージ）が「当たり」かを、何も構築する前に判定する。
#
# 外れホストに構築の手間を払わないための事前チェック (pooza/chubo2#68)。
# 遅ければその場で削除して作り直す。判定は 2 分で済む。
#
#   docs/bench/probe_host.sh root@203.0.113.10
#
#   exit 0 = 当たり。このホストの上で OS 構築を始めてよい
#   exit 1 = 外れ。削除して作り直す
#   exit 2 = 実行エラー
#
# 素のイメージにはコンパイラが無いので、ローカルで静的バイナリを作って送り込む。
# 構築後の FreeBSD 機に対しては verify_host.sh のほうを使うこと。
set -u

TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "usage: $0 <user@host>" >&2; exit 2; }

KNOWN_BAD_HOST='a6f7baf248a8c508184174f3e75b5c1a30b551ae'
THRESHOLD_MS='15.0'
SRC="$(dirname "$0")/chunk_bench.c"
SSH_OPTS='-o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new'

[ -f "$SRC" ] || { echo "chunk_bench.c が見つかりません: $SRC" >&2; exit 2; }

BIN=$(mktemp) || exit 2
trap 'rm -f "$BIN"' EXIT
cc -O2 -static -o "$BIN" "$SRC" 2>/dev/null \
  || { echo "静的バイナリのビルドに失敗（cc と静的 libc が要ります）" >&2; exit 2; }

echo "=== $TARGET"

# shellcheck disable=SC2086
meta=$(ssh $SSH_OPTS "$TARGET" '
  T=$(curl -s -m 5 -X PUT http://169.254.169.254/v1/token \
        -H "Metadata-Token-Expiry-Seconds: 120" 2>/dev/null)
  [ -n "$T" ] && curl -s -m 5 http://169.254.169.254/v1/instance -H "Metadata-Token: $T" 2>/dev/null
') || { echo "SSH 失敗" >&2; exit 2; }

uuid=$(echo "$meta" | sed -n 's/^host_uuid: //p')
echo "  plan      : $(echo "$meta" | sed -n 's/^type: //p') / $(echo "$meta" | sed -n 's/^region: //p')"
echo "  host_uuid : ${uuid:-取得できず}"

# shellcheck disable=SC2086
scp $SSH_OPTS -q "$BIN" "$TARGET:/tmp/chunk_bench" \
  || { echo "バイナリの転送に失敗" >&2; exit 2; }
# shellcheck disable=SC2086
bench=$(ssh $SSH_OPTS "$TARGET" 'chmod +x /tmp/chunk_bench && /tmp/chunk_bench; rm -f /tmp/chunk_bench') \
  || { echo "ベンチ実行に失敗" >&2; exit 2; }
echo "  $bench"

min=$(echo "$bench" | sed -n 's/^min *\([0-9.]*\).*/\1/p')

fail=0
if [ "$uuid" = "$KNOWN_BAD_HOST" ]; then
  echo "  ✗ 既知の遅いホストです"
  fail=1
fi
if [ -z "$min" ]; then
  echo "  ⚠ min を取得できませんでした"
  fail=1
elif awk "BEGIN{exit !($min < $THRESHOLD_MS)}"; then
  echo "  ✓ min ${min}ms < ${THRESHOLD_MS}ms"
else
  echo "  ✗ min ${min}ms >= ${THRESHOLD_MS}ms"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "  → 当たり。このホストで OS 構築を始めてよい"
  exit 0
fi
echo "  → 外れ。削除して作り直す（まだ何も構築していないので損失なし）"
exit 1
