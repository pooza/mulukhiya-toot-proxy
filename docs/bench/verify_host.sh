#!/bin/sh
# 構築済みの機体に store->load forwarding の異常が無いかを見る (pooza/chubo2#68)
#
#   docs/bench/verify_host.sh <target> [reference]
#   docs/bench/verify_host.sh gomander.b-shock.co.jp            # 既定の参照と比較
#   docs/bench/verify_host.sh gomander.b-shock.co.jp lbock.b-shock.co.jp
#
#   exit 0 = 参照と同等。この個体で進めてよい
#   exit 1 = 参照より明らかに遅い。作り直しを検討する
#   exit 2 = 実行エラー、または参照が測れず判定を出せない
#
# ⚠ 絶対閾値では判定しない (#4476)。
#
# stlf_probe の ratio は**同一ツールチェーンで測ったときだけ**比較できる。
# 同じソース・同じ -O2 でも、コンパイラを変えるだけで健全な機体の ratio が
# 3〜5 倍動く（Debian 13 / i7-1270P 実測: gcc 0.113 / clang 0.177。分母を
# 別アドレスの連鎖に変えた案でも gcc 0.737 / clang 3.629）。
# 分子である同一アドレス側の絶対時間からしてコンパイラ依存で、30M 回 13.5ms
# ≒ 1.2 cycle/iter は forwarding の遅延より速い。つまり測っているのは CPU の
# 特性よりコード生成の差で、どんな分母を選んでも不変な絶対閾値にはできない。
#
# 旧 gomander の切り分け（0.569 対 他 0.1）が有効だったのは、4 台すべてを
# FreeBSD の clang・同一ソースで測った**相対比較**だったから。ここでも同じ
# ソースを両方へ送って測り、比だけを見る。
#
# かつての host_uuid 判定も無効（Cold Resize で uuid が変わっても数字が動かず
# 反証済み。既知の 1 台と比べる方式では別の遅い個体を検出できない）。
# chunk_bench の生スループットも合否には使わない（C の速度は Ruby の速度を
# 予測しない。新 gomander は C で 6% 速いのに Ruby では 10% 遅い）。
set -u

TARGET="${1:-}"
REFERENCE="${2:-zugoga.b-shock.co.jp}"
[ -n "$TARGET" ] || { echo "usage: $0 <target> [reference]" >&2; exit 2; }

DIR="$(dirname "$0")"
PROBE="$DIR/stlf_probe.c"
# 参照の 2 倍までは同等とみなす（健全な 4 台の実測は 0.098〜0.153 で 1.6 倍に収まる）。
# 3 倍以上を異常とする（旧 gomander は 5.7 倍だった）。
SAME_MAX='2.0'
AFFLICTED_MIN='3.0'

[ -f "$PROBE" ] || { echo "stlf_probe.c が見つかりません: $PROBE" >&2; exit 2; }

# 同じソースを送ってその場でビルドし、ratio だけを拾う。測れなければ空を返す。
measure() {
  ssh -o ConnectTimeout=10 "pooza@$1" \
    'cat > /tmp/stlf.c && cc -O2 -o /tmp/stlf /tmp/stlf.c 2>/dev/null && /tmp/stlf; rm -f /tmp/stlf /tmp/stlf.c' \
    < "$PROBE" 2>/dev/null | sed -n 's/^ *ratio *: *\([0-9.]*\).*/\1/p'
}

echo "=== target    : $TARGET"
t_ratio=$(measure "$TARGET")
[ -n "$t_ratio" ] || { echo "  ✗ 測定に失敗しました（SSH か cc を確認）" >&2; exit 2; }
echo "  ratio       : $t_ratio"

echo "=== reference : $REFERENCE"
r_ratio=$(measure "$REFERENCE")
if [ -z "$r_ratio" ]; then
  echo "  ⚠ 参照を測れませんでした。絶対値では判定できないので合否は出しません。"
  echo "  → 健全と分かっている同系の機体を指定して測り直してください。"
  exit 2
fi
echo "  ratio       : $r_ratio"

rel=$(awk "BEGIN{printf \"%.2f\", $t_ratio / $r_ratio}")
echo "=== target / reference = ${rel}x"

if awk "BEGIN{exit !($rel <= $SAME_MAX)}"; then
  echo "  → 参照と同等。この個体で進めてよい"
  exit 0
fi
if awk "BEGIN{exit !($rel >= $AFFLICTED_MIN)}"; then
  echo "  → 参照より明らかに遅い。作り直しを検討する"
  exit 1
fi
echo "  → 判定不能（${SAME_MAX}x〜${AFFLICTED_MIN}x の中間）。時間を空けて測り直す"
exit 2
