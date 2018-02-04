
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "bfs.hpp"
#include "bfs.h"

template <class Item>
using parray = sptl::parray<Item>;

void benchmark(sptl::bench::measured_type measured) {
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  int source = deepsea::cmdline::parse_or_default_int("source", 0);
  if (infile == "") {
    sptl::die("missing infile");
  }
  sptl::graph::graph<intT> x = sptl::read_from_file<sptl::graph::graph<intT>>(infile);
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  std::pair<intT,intT> pbbs_results;
  std::pair<intT,intT> sptl_results;
  auto do_pbbs = [&] {
    parray<pbbs::graph::vertex<int>> vs(x.n, [&] (int i) {
      return pbbs::graph::vertex<int>(x.V[i].Neighbors, x.V[i].degree);
    });
    pbbs::graph::graph<intT> y(vs.begin(), x.n, x.m, x.allocatedInplace);
    measured([&] {
      pbbs_results = pbbs::BFS(source, y);
    });
  };
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", do_pbbs);
  d.add("sptl", [&] {
    measured([&] {
      sptl_results = sptl::bfs(source, x);
    });
    if (should_check) {
      do_pbbs();
      if (pbbs_results.first != sptl_results.first) {
        sptl::die("error");
      }
      if (pbbs_results.second != sptl_results.second) {
        sptl::die("error");
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
