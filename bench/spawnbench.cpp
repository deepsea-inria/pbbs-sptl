#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

using uint64 = unsigned long long;

namespace sptl {

int* array;

  // This must execute EXACTLY n forks.
uint64 spawntree_seq(uint64 n, uint64 i) {
  uint64 r;
  if (n==0) {
    return array[i];
  }
  // First we split without losing any:
  uint64 half1 = n / 2;
  uint64 half2 = half1 + (n % 2);
  // We subtract one from our total, because of *this* spawn:
  uint64 x,y;
  y = spawntree_seq(half1, i);
  x = spawntree_seq(half2 - 1, i + half1);
  r = x + y;
  return r;
}

// This must execute EXACTLY n forks.
uint64 spawntree(uint64 n, uint64 i) {
  uint64 r;
  spguard([&] { return n; }, [&] {
    if (n==0) {
      r = 1;
      return;
    }
    // First we split without losing any:
    uint64 half1 = n / 2;
    uint64 half2 = half1 + (n % 2);
    // We subtract one from our total, because of *this* spawn:
    uint64 x,y;
    fork2([&] {
      y = spawntree(half1, i);
    }, [&] {
      x = spawntree(half2 - 1, i + half1);
    });
    r = x + y;
  }, [&] {
    r = spawntree_seq(n, i);
  });
  return r;
}

} // end namespace

void benchmark(sptl::bench::measured_type measured) {
  uint64 n = deepsea::cmdline::parse_or_default_int("n", 200000000);
  uint64 r = 0;
  sptl::array = (int*)malloc(sizeof(int) * n);
  for (uint64 i = 0; i < n; i++) {
    sptl::array[i] = i;
  }
  measured([&] {
    r = sptl::spawntree(n, 0);
  });
  free(sptl::array);
  printf("result %lld\n", r);
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    benchmark(measured);
  });
}
