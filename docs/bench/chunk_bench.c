/*
 * ホストの素の CPU 速度を Ruby 抜きで測り、「素で遅い」と「隣人に奪われている」を
 * 分布で切り分けるベンチ (#4464 / pooza/chubo2#68)。
 *
 * min  … 誰にも邪魔されない最良ケース。ここが遅ければ素の速度が遅い。
 * max/min … テール。大きければ steal を食らっている。
 *
 *   ssh pooza@<host> 'cat > /tmp/chunk.c && cc -O2 -o /tmp/chunk /tmp/chunk.c && /tmp/chunk' \
 *     < docs/bench/chunk_bench.c
 *
 * 2026-07-20 の基準値: zugoga min 14.22 / lbock min 15.11 / gomander min 20.05 ms。
 */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#define CHUNKS 400
#define ITERS  3000000ULL
static int cmp(const void *a, const void *b){
  double x=*(const double*)a, y=*(const double*)b;
  return (x>y)-(x<y);
}
int main(void){
  static double t[CHUNKS];
  volatile uint64_t x=0;
  for(int c=0;c<CHUNKS;c++){
    struct timespec a,b;
    clock_gettime(CLOCK_MONOTONIC,&a);
    for(uint64_t i=0;i<ITERS;i++) x=(x+i)%1000003ULL;
    clock_gettime(CLOCK_MONOTONIC,&b);
    t[c]=(b.tv_sec-a.tv_sec)*1000.0+(b.tv_nsec-a.tv_nsec)/1e6;
  }
  qsort(t,CHUNKS,sizeof(double),cmp);
  double sum=0; for(int i=0;i<CHUNKS;i++) sum+=t[i];
  printf("min %7.2f  p50 %7.2f  p90 %7.2f  p99 %7.2f  max %7.2f  mean %7.2f  (p50/min %.3f)\n",
    t[0], t[CHUNKS/2], t[(int)(CHUNKS*0.9)], t[(int)(CHUNKS*0.99)], t[CHUNKS-1],
    sum/CHUNKS, t[CHUNKS/2]/t[0]);
  return 0;
}
