
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "spanning.hpp"
#include "spanning.h"

template <class Item>
using parray = sptl::parray<Item>;

namespace sptl {
namespace graph {
  
template <class intT>
edgeArray<intT> to_edge_array(graph<intT>& G) {
  int num_rows = G.n;
  int non_zeros = G.m;
  vertex<intT>* v = G.V;
  edge<intT>* e = newA(edge<intT>, non_zeros);

  int k = 0;
  for (int i = 0; i < num_rows; i++) {
    for (int j = 0; j < v[i].degree; j++) {
      if (i < v[i].Neighbors[j]) {
        e[k++] = edge<int>(i, v[i].Neighbors[j]);
      }
    }
  }
  return edgeArray<intT>(e, num_rows, num_rows, non_zeros);
}

} // end namespace
} // end namespace

void benchmark(sptl::bench::measured_type measured) {
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  if (infile == "") {
    sptl::die("missing infile");
  }
  sptl::graph::graph<intT> x = sptl::read_from_file<sptl::graph::graph<intT>>(infile);
  sptl::graph::edgeArray<intT> edges = to_edge_array(x);
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  parray<intT> sptl_results;
  std::pair<intT*,intT> pbbs_results;
  pbbs_results.first = nullptr;
  auto do_pbbs = [&] {
    parray<pbbs::graph::edge<intT>> edges2(edges.nonZeros, [&] (intT i) {
      return pbbs::graph::edge<intT>(edges.E[i].u, edges.E[i].v);
    });
    pbbs::graph::edgeArray<intT> y(edges2.begin(), edges.numRows, edges.numCols, edges.nonZeros);
    measured([&] {
      pbbs_results = pbbs::spanningTree(y);
    });
  };
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", do_pbbs);
  d.add("sptl", [&] {
    measured([&] {
      sptl_results = sptl::spanningTree(edges);
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
