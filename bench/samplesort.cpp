
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "samplesort.hpp"
#include "sampleSort.h"

template <class Item>
using parray = sptl::parray<Item>;

template <class Item, class Compare>
void benchmark(sptl::bench::measured_type measured,
               parray<Item>& x,
               const Compare& compare) {
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  parray<Item> ref;
  if (should_check) {
    ref = x;
  }
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", [&] {
    measured([&] {
      pbbs::sampleSort(x.begin(), (int)x.size(), compare);
    });
  });
  d.add("sptl", [&] {
    measured([&] {
     sptl::sample_sort(x.begin(), (int)x.size(), compare);
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

template <class Item, class Compare, class Destroy>
void benchmark(sptl::bench::measured_type measured,
               const Compare& compare,
               const Destroy& destroy) {
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  if (infile == "") {
    sptl::die("missing infile");
  }
  parray<Item> x = sptl::read_from_file<parray<Item>>(infile);
  benchmark(measured, x, compare);
  destroy(x);
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    deepsea::cmdline::dispatcher d;
    d.add("double", [&] {
      benchmark<double>(measured, std::less<double>(), [] (parray<double>& xs) { });
    });
    d.add("int", [&]  {
      benchmark<int>(measured, std::less<int>(), [] (parray<int>& xs) { });
    });
    d.add("string", [&]  {
      benchmark<char*>(measured, [&] (char* a, char* b) {
          return std::strcmp(a, b) < 0;
        }, [] (parray<char*>& xs) {
          for (int i = 0; i < xs.size(); i++) {
            delete [] xs[i];
          }
        });
    });
    d.dispatch("type");
  });
}
