
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "blockradixsort.hpp"
#include "blockRadixSort.h"

template <class Item>
using parray = sptl::parray<Item>;

template <class Item>
void benchmark(sptl::bench::measured_type measured, parray<Item>& x) {
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  parray<Item> ref;
  if (should_check) {
    ref = x;
  }
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", [&] {
    measured([&] {
      pbbs::integerSort<int>(&x[0], (int)x.size());
    });
  });
  d.add("sptl", [&] {
    measured([&] {
      sptl::integer_sort(x.begin(), (int)x.size());
    });
    if (should_check) {
      std::sort(ref.begin(), ref.end());
      auto it_ref = ref.begin();
      for (auto it = x.begin(); it != x.end(); it++) {
        if (*it != *it_ref) {
          std::cerr << "bogus result" << std::endl;
          exit(0);
        }
        it_ref++;
      }
    }
  });
  d.dispatch("library");
}

template <class Item>
void benchmark(sptl::bench::measured_type measured) {
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  if (infile == "") {
    sptl::die("missing infile");
  }
  parray<Item> x = sptl::read_from_file<parray<Item>>(infile);
  benchmark(measured, x);
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    deepsea::cmdline::dispatcher d;
    d.add("int", [&] {
      benchmark<int>(measured);
    });
    d.add("pair_int_int", [&]  {
      benchmark<std::pair<int, int>>(measured);
    });
    d.dispatch("type");
  });
}
