/*
 * store-to-load forwarding が効いているかを判定する (pooza/chubo2#68)
 *
 * gomander は同一プラン・同一リージョン・同一マイクロコードの zugoga に対し、
 * 実 Ruby で 1.57 倍遅い。原因は未特定だが、同一バイナリでの分解により
 * 「同一アドレスへのストア直後に同じアドレスをロードする」パターンだけが
 * 突出して遅いことが分かっている。ALU も L1 配列アクセスも同速。
 *
 * 判定は同一マシン内の 2 つの数字の比で行う。絶対値で比べると OS・libc・
 * コンパイラ・CPU 世代の差が混入するが、比なら自己正規化されるため、
 * Linux でも FreeBSD でも、Intel でも AMD でも同じ基準で使える。
 *
 *   ratio = (volatile 変数の読み書きループ) / (レジスタ内で完結する除算ループ)
 *
 * 2026-07-20 の実測:
 *   zugoga   (健全 / FreeBSD 14 / EPYC 7713) : 13.3 / 132.2 = 0.10
 *   lbock    (健全 / FreeBSD 14 / Xeon SPR)  : 21.7 / 143.4 = 0.15
 *   gomander (異常 / FreeBSD 15 / EPYC 7713) : 79.7 / 131.2 = 0.61
 *
 * ビルド:
 *   cc -O2 -static -o stlf_probe stlf_probe.c
 */
#include <stdio.h>
#include <time.h>
#include <stdint.h>

#define N 30000000ULL
#define HEALTHY_MAX 0.30
#define AFFLICTED_MIN 0.50

static double el(struct timespec a, struct timespec b) {
  return (b.tv_sec - a.tv_sec) + (b.tv_nsec - a.tv_nsec) / 1e9;
}

int main(void) {
  struct timespec s, e;
  volatile uint64_t sink = 0;
  double mem, alu;

  /* 同一アドレスへの store→load を毎回発行する。ここが遅いかを見る */
  {
    volatile uint64_t x = 0;
    clock_gettime(CLOCK_MONOTONIC, &s);
    for (uint64_t i = 0; i < N; i++) x = x + i;
    clock_gettime(CLOCK_MONOTONIC, &e);
    sink += x;
    mem = el(s, e) * 1000;
  }

  /* レジスタ内で完結する除算。CPU 素の速度の基準値として使う */
  {
    uint64_t x = 0;
    clock_gettime(CLOCK_MONOTONIC, &s);
    for (uint64_t i = 0; i < N; i++) x = (x + i) % 1000003ULL;
    clock_gettime(CLOCK_MONOTONIC, &e);
    sink += x;
    alu = el(s, e) * 1000;
  }

  double ratio = mem / alu;
  printf("  store->load : %7.1f ms\n", mem);
  printf("  register    : %7.1f ms\n", alu);
  printf("  ratio       : %7.3f  ", ratio);

  if (ratio <= HEALTHY_MAX) {
    printf("健全（store->load forwarding が効いている）\n");
    return (int)(sink & 0);
  }
  if (ratio >= AFFLICTED_MIN) {
    printf("異常（gomander と同じ症状）\n");
    return 1;
  }
  printf("判定不能（基準値の中間。要再測定）\n");
  return 2;
}
