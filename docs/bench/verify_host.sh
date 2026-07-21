#!/bin/sh
# 構築済みの Linode 機が健全かを判定する (pooza/chubo2#68)
#
#   docs/bench/verify_host.sh [host]        # 既定 gomander.b-shock.co.jp
#
#   exit 0 = 合格。この個体で進めてよい
#   exit 1 = 不合格。作り直して別の個体を狙う
#   exit 2 = 実行エラー
#
# 判定は stlf_probe の ratio ただ一つ（ratio <= 0.30 が健全）。
#
# かつては「host_uuid が既知の遅いホストと違うこと」と「chunk_bench の min が
# 15ms 未満であること」で判定していたが、どちらも無効と判明した (#4471)。
#
#   - host_uuid: 旧 gomander の遅さを物理ホストのせいと見ていたが、Cold Resize で
#     host_uuid が変わっても数字が動かず反証された。既知の 1 台と UUID を比べる
#     方式は「別の遅い個体」を検出できないので、そもそも判定にならない。
#   - chunk_bench の生スループット: C の速度は Ruby の速度を予測しない。
#     新 gomander は C では lbock より 6% 速いのに Ruby では 10% 遅い。
#
# 残った症状の形は「同一アドレスへの store->load だけ 6 倍遅い」で、これは
# stlf_probe が直接測る。健全な個体 (0.098〜0.153) と病んだ個体 (0.569) は
# 5 倍以上離れており、閾値 0.30 に対して十分な余裕がある。
set -u

HOST="${1:-gomander.b-shock.co.jp}"
DIR="$(dirname "$0")"
PROBE="$DIR/stlf_probe.c"
CHUNK="$DIR/chunk_bench.c"

[ -f "$PROBE" ] || { echo "stlf_probe.c が見つかりません: $PROBE" >&2; exit 2; }

echo "=== $HOST"

ssh -o ConnectTimeout=10 "pooza@$HOST" true || { echo "SSH 失敗" >&2; exit 2; }

# 記録用。判定には使わない。Linode 以外（さくら VPS 等）ではメタデータサービスが
# 無く空になるが、それで止めない（末尾の : で必ず成功させる）。
meta=$(ssh -o ConnectTimeout=10 "pooza@$HOST" '
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

# 参考値。合否には使わない。
if [ -f "$CHUNK" ]; then
  chunk=$(ssh -o ConnectTimeout=10 "pooza@$HOST" \
    'cat > /tmp/chunk.c && cc -O2 -o /tmp/chunk /tmp/chunk.c && /tmp/chunk; rm -f /tmp/chunk /tmp/chunk.c' < "$CHUNK") \
    && echo "  参考 (chunk_bench): $chunk"
fi

probe=$(ssh -o ConnectTimeout=10 "pooza@$HOST" \
  'cat > /tmp/stlf.c && cc -O2 -o /tmp/stlf /tmp/stlf.c && /tmp/stlf; s=$?; rm -f /tmp/stlf /tmp/stlf.c; exit $s' < "$PROBE")
status=$?
echo "$probe" | sed 's/^/  /'

case "$status" in
  0) echo "  → 合格。この個体で進めてよい"; exit 0 ;;
  1) echo "  → 不合格。作り直して別の個体を狙う"; exit 1 ;;
  2) echo "  → 判定不能（基準値の中間）。時間を空けて再測定する"; exit 1 ;;
  *) echo "  ✗ stlf_probe の実行に失敗しました (exit $status)" >&2; exit 2 ;;
esac
