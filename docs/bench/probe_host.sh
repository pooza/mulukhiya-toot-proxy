#!/bin/sh
# 作った直後の Linode（素の Linux イメージ）が健全かを、何も構築する前に判定する。
#
# 病んだ個体に構築の手間を払わないための事前チェック (pooza/chubo2#68)。
# 遅ければその場で削除して作り直す。判定は 2 分で済む。
#
#   docs/bench/probe_host.sh root@203.0.113.10
#
#   exit 0 = 健全。このホストの上で OS 構築を始めてよい
#   exit 1 = 異常。削除して作り直す
#   exit 2 = 実行エラー
#
# 判定基準と、かつての host_uuid / chunk_bench 方式を捨てた理由は
# verify_host.sh の冒頭コメントを参照 (#4471)。
#
# 素のイメージにはコンパイラが無いので、ローカルで静的バイナリを作って送り込む。
# 構築後の FreeBSD 機に対しては verify_host.sh のほうを使うこと。
set -u

TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "usage: $0 <user@host>" >&2; exit 2; }

DIR="$(dirname "$0")"
PROBE="$DIR/stlf_probe.c"
SSH_OPTS='-o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new'

[ -f "$PROBE" ] || { echo "stlf_probe.c が見つかりません: $PROBE" >&2; exit 2; }

BIN=$(mktemp) || exit 2
trap 'rm -f "$BIN"' EXIT
cc -O2 -static -o "$BIN" "$PROBE" 2>/dev/null \
  || { echo "静的バイナリのビルドに失敗（cc と静的 libc が要ります）" >&2; exit 2; }

echo "=== $TARGET"

# shellcheck disable=SC2086
ssh $SSH_OPTS "$TARGET" true || { echo "SSH 失敗" >&2; exit 2; }

# 記録用。判定には使わない。メタデータが取れなくても止めない。
# shellcheck disable=SC2086
meta=$(ssh $SSH_OPTS "$TARGET" '
  T=$(curl -s -m 5 -X PUT http://169.254.169.254/v1/token \
        -H "Metadata-Token-Expiry-Seconds: 120" 2>/dev/null)
  [ -n "$T" ] && curl -s -m 5 http://169.254.169.254/v1/instance -H "Metadata-Token: $T" 2>/dev/null
  :
')

if [ -n "$meta" ]; then
  echo "  plan      : $(echo "$meta" | sed -n 's/^type: //p') / $(echo "$meta" | sed -n 's/^region: //p')"
  echo "  host_uuid : $(echo "$meta" | sed -n 's/^host_uuid: //p')  (記録用・判定には使わない)"
else
  echo "  metadata  : 取得できず（Linode 以外のホストか、メタデータサービス不通）"
fi

# shellcheck disable=SC2086
scp $SSH_OPTS -q "$BIN" "$TARGET:/tmp/stlf_probe" \
  || { echo "バイナリの転送に失敗" >&2; exit 2; }
# shellcheck disable=SC2086
probe=$(ssh $SSH_OPTS "$TARGET" 'chmod +x /tmp/stlf_probe && /tmp/stlf_probe; s=$?; rm -f /tmp/stlf_probe; exit $s')
status=$?
echo "$probe" | sed 's/^/  /'

case "$status" in
  0) echo "  → 健全。このホストで OS 構築を始めてよい"; exit 0 ;;
  1) echo "  → 異常。削除して作り直す（まだ何も構築していないので損失なし）"; exit 1 ;;
  2) echo "  → 判定不能（基準値の中間）。時間を空けて再測定する"; exit 1 ;;
  *) echo "  ✗ stlf_probe の実行に失敗しました (exit $status)" >&2; exit 2 ;;
esac
