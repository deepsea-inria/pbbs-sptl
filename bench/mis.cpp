
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "mis.hpp"
#include "mis.h"

template <class Item>
using parray = sptl::parray<Item>;

void benchmark(sptl::bench::measured_type measured) {
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  if (infile == "") {
    sptl::die("missing infile");
  }
  sptl::graph::graph<intT> x = sptl::read_from_file<sptl::graph::graph<intT>>(infile);
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  parray<char> sptl_results;
  char* pbbs_results = nullptr;
  auto do_pbbs = [&] {
    parray<pbbs::graph::vertex<intT>> vs(x.n, [&] (intT i) {
      return pbbs::graph::vertex<intT>(x.V[i].Neighbors, x.V[i].degree);
    });
    pbbs::graph::graph<intT> y(vs.begin(), x.n, x.m, x.allocatedInplace);
    measured([&] {
      pbbs_results = pbbs::maximalIndependentSet(y);
    });
  };
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", do_pbbs);
  d.add("sptl", [&] {
    measured([&] {
      sptl_results = sptl::maximalIndependentSet(x);
    });
    if (should_check) {
      do_pbbs();
      for (intT i = 0; i < sptl_results.size(); i++) {
        if (sptl_results[i] != pbbs_results[i]) {
          sptl::die("bogus result at index %d\n", i);
        }
      }
    }
  });
  d.dispatch("library");
  if (pbbs_results != nullptr) {
    free(pbbs_results);
  }
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    benchmark(measured);
  });
}
