
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "mst.hpp"
#include "mst.h"

template <class Item>
using parray = sptl::parray<Item>;

namespace sptl {
namespace graph {
  
template <class intT>
wghEdgeArray<intT> to_weighted_edge_array(graph<intT>& G) {
  int n = G.n;
  int m = G.m;
  vertex<intT>* v = G.V;
  wghEdge<intT>* e = newA(wghEdge<intT>, m);

  int k = 0;
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < v[i].degree; j++) {
      if (i < v[i].Neighbors[j]) {
        e[k++] = wghEdge<intT>(i, v[i].Neighbors[j], hashi(k));
      }
    }
  }
  return wghEdgeArray<int>(e, n, m);
}

} // end namespace
} // end namespace

void benchmark(sptl::bench::measured_type measured) {
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  if (infile == "") {
    sptl::die("missing infile");
  }
  sptl::graph::graph<intT> x = sptl::read_from_file<sptl::graph::graph<intT>>(infile);
  sptl::graph::wghEdgeArray<int> edges = to_weighted_edge_array(x);
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  parray<sptl::size_type> sptl_results;
  std::pair<intT*,intT> pbbs_results;
  pbbs_results.first = nullptr;
  auto do_pbbs = [&] {
    parray<pbbs::graph::wghEdge<intT>> edges2(edges.m, [&] (intT i) {
      return pbbs::graph::wghEdge<int>(edges.E[i].u, edges.E[i].v, edges.E[i].weight);
    });
    pbbs::graph::wghEdgeArray<intT> y(edges2.begin(), edges.n, edges.m);
    measured([&] {
      pbbs_results = pbbs::mst(y);
    });
  };
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", do_pbbs);
  d.add("sptl", [&] {
    measured([&] {
      sptl::mst(edges);
    });
    if (should_check) {
      do_pbbs();
      for (intT i = 0; i < sptl_results.size(); i++) {
        if (sptl_results[i] != pbbs_results.first[i]) {
          sptl::die("bogus result at index %d\n", i);
        }
      }
    }
  });
  d.dispatch("library");
  if (pbbs_results.first != nullptr) {
    free(pbbs_results.first);
  }
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    benchmark(measured);
  });
}
