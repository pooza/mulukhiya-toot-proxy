#!/bin/sh
# 作った直後の素の Linux イメージを、何も構築する前に測る (pooza/chubo2#68)。
#
#   docs/bench/probe_host.sh <target> [reference]
#   docs/bench/probe_host.sh root@203.0.113.10
#   docs/bench/probe_host.sh root@203.0.113.10 root@203.0.113.11
#
#   exit 0 = 参照と同等、または参照なしで数値のみ出力（合否は出していない）
#   exit 1 = 参照より明らかに遅い。削除して作り直す
#   exit 2 = 実行エラー
#
# ⚠ 参照を渡さない限り合否は出さない (#4476)。
#
# stlf_probe の ratio に不変な絶対閾値は置けない。健全な機体でもコンパイラや
# CPU が変われば 3〜5 倍動く。詳しい実測は verify_host.sh の冒頭コメント参照。
#
# ここではローカルで静的バイナリを 1 つ作り、target と reference の**両方に
# 同じバイナリ**を送って測る。コード生成の差が消えるので、残る変数は CPU だけ
# になる。判定できるのは「同じイメージで作った 2 台のどちらかが遅い」形。
#
# 構築後の FreeBSD 機に対しては verify_host.sh のほうを使うこと。
set -u

TARGET="${1:-}"
REFERENCE="${2:-}"
[ -n "$TARGET" ] || { echo "usage: $0 <target> [reference]" >&2; exit 2; }

DIR="$(dirname "$0")"
PROBE="$DIR/stlf_probe.c"
SSH_OPTS='-o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new'
SAME_MAX='2.0'
AFFLICTED_MIN='3.0'

[ -f "$PROBE" ] || { echo "stlf_probe.c が見つかりません: $PROBE" >&2; exit 2; }

BIN=$(mktemp) || exit 2
trap 'rm -f "$BIN"' EXIT
cc -O2 -static -o "$BIN" "$PROBE" 2>/dev/null \
  || { echo "静的バイナリのビルドに失敗（cc と静的 libc が要ります）" >&2; exit 2; }

# 同一バイナリを送って ratio だけを拾う。測れなければ空を返す。
measure() {
  # shellcheck disable=SC2086
  scp $SSH_OPTS -q "$BIN" "$1:/tmp/stlf_probe" 2>/dev/null || return 0
  # shellcheck disable=SC2086
  ssh $SSH_OPTS "$1" 'chmod +x /tmp/stlf_probe && /tmp/stlf_probe; rm -f /tmp/stlf_probe' 2>/dev/null \
    | sed -n 's/^ *ratio *: *\([0-9.]*\).*/\1/p'
}

echo "=== target    : $TARGET"
t_ratio=$(measure "$TARGET")
[ -n "$t_ratio" ] || { echo "  ✗ 測定に失敗しました（SSH を確認）" >&2; exit 2; }
echo "  ratio       : $t_ratio"

if [ -z "$REFERENCE" ]; then
  echo "  ⚠ 参照が指定されていないので合否は出しません。"
  echo "  → 同じイメージで作ったもう 1 台を第 2 引数に渡すと比較できます。"
  exit 0
fi

echo "=== reference : $REFERENCE"
r_ratio=$(measure "$REFERENCE")
if [ -z "$r_ratio" ]; then
  echo "  ⚠ 参照を測れませんでした。合否は出しません。" >&2
  exit 2
fi
echo "  ratio       : $r_ratio"

rel=$(awk "BEGIN{printf \"%.2f\", $t_ratio / $r_ratio}")
echo "=== target / reference = ${rel}x"

if awk "BEGIN{exit !($rel <= $SAME_MAX)}"; then
  echo "  → 参照と同等。このホストで OS 構築を始めてよい"
  exit 0
fi
if awk "BEGIN{exit !($rel >= $AFFLICTED_MIN)}"; then
  echo "  → 参照より明らかに遅い。削除して作り直す（まだ何も構築していないので損失なし）"
  exit 1
fi
echo "  → 判定不能（${SAME_MAX}x〜${AFFLICTED_MIN}x の中間）。時間を空けて測り直す"
exit 2
