#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

using uint64 = unsigned long long;

namespace sptl {

// This must execute EXACTLY n forks.
uint64 spawntree(uint64 n) {
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
      y = spawntree(half1);
    }, [&] {
      x = spawntree(half2 - 1);
    });
    r = x + y;
  });
  return r;
}

} // end namespace

void benchmark(sptl::bench::measured_type measured) {
  uint64 n = deepsea::cmdline::parse_or_default_int("n", 100000000);
  uint64 r = 0;
  measured([&] {
    r = sptl::spawntree(n);
  });
  printf("result %lld\n", r);
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    benchmark(measured);
  });
}
