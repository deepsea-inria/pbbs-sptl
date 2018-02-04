
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "suffixarray.hpp"
#include "pks.h"

template <class Item>
using parray = sptl::parray<Item>;

void benchmark(sptl::bench::measured_type measured) {
  if (sizeof(sptl::intT) != sizeof(intT)) {
    sptl::die("mismatch in intT type");
  }
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  if (infile == "") {
    sptl::die("missing infile");
  }
  std::string x = sptl::read_from_file<std::string>(infile);
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  sptl::intT* pbbs_result;
  parray<sptl::intT> sptl_result;
  auto do_pbbs = [&] {
    measured([&] {
      pbbs_result = pbbs::suffixArray(&x[0], (sptl::intT)x.length());
    });
  };
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", do_pbbs);
  d.add("sptl", [&] {
    measured([&] {
      sptl_result = sptl::suffix_array(&x[0], x.length());
    });
    if (should_check) {
      do_pbbs();
      for (auto i = 0; i < x.length(); i++) {
        if (pbbs_result[i] != sptl_result[i]) {
          sptl::die("failed at index %d", i);
        }
      }
    }
  });
  d.dispatch("library");
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    benchmark(measured);
  });
}
