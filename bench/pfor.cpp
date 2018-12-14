
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#undef parallel_for
#undef parallel_for_1
#define parallel_for cilk_for
#define parallel_for_1 _Pragma("cilk grainsize = 1") cilk_for
#define parallel_for_1m _Pragma("cilk grainsize = 1000000") cilk_for

long fib(long n){
  if (n < 2) {
    return n;
  } else { 
    return fib (n - 1) + fib (n - 2);
  }
}

template <class Item>
using parray = sptl::parray<Item>;

void benchmark(sptl::bench::measured_type measured) {
  long n = deepsea::cmdline::parse_or_default_int("n", 1000000);
  parray<long> vals(n);
  deepsea::cmdline::dispatcher d;
  int mx = 25;
  d.add("1", [&] {
    measured([&] {
      parallel_for_1 (long i = 0; i < n; ++i) {
        vals[i] = fib(i % mx);
      }
    });
  });
  d.add("1m", [&] {
    measured([&] {
      parallel_for_1m (long i = 0; i < n; ++i) {
        vals[i] = fib(i % mx);
      }
    });
  });
  d.add("default", [&] {
    measured([&] {
      parallel_for (long i = 0; i < n; ++i) {
        vals[i] = fib(i % mx);
      }
    });
  });
  d.dispatch("loop_strategy");
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    benchmark(measured);
  });
}
