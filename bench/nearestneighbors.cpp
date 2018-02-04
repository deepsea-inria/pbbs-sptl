
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "nearestneighbors.hpp"
#include "nearestNeighbors.h"

template <class Item>
using parray = sptl::parray<Item>;

static constexpr
int K = 10;

static constexpr
int k = 1;

template <class Item_sptl, class Item_pbbs, class Convert_to_pbbs>
void benchmark(sptl::bench::measured_type measured,
               parray<Item_sptl>& x,
               const Convert_to_pbbs& convert_to_pbbs) {
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  parray<intT> pbbs_result;
  parray<intT> sptl_result;
  intT n = x.size();
  auto do_pbbs = [&] {
    pbbs_result.reset(n * k);
    parray<Item_pbbs> y = convert_to_pbbs(x);
    measured([&] {
      pbbs::findNearestNeighbors<K, Item_pbbs>(&y[0], n, k, pbbs_result.begin());
    });
  };
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", do_pbbs);
  d.add("sptl", [&] {
    measured([&] {
      sptl_result = sptl::ANN<int, K, Item_sptl>(x, (int)x.size(), k);
    });
    if (should_check) {
      do_pbbs();
      for (intT i = 0; i < pbbs_result.size(); i++) {
        if (pbbs_result[i] != sptl_result[i]) {
          sptl::die("bogus value at index\n");
        }
      }
    }
  });
  d.dispatch("library");
}

template <class Item_sptl, class Item_pbbs, class Convert_to_pbbs>
void benchmark(sptl::bench::measured_type measured,
               const Convert_to_pbbs& convert_to_pbbs) {
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  if (infile == "") {
    sptl::die("missing infile");
  }
  parray<Item_sptl> x = sptl::read_from_file<parray<Item_sptl>>(infile);
  benchmark<Item_sptl, Item_pbbs, Convert_to_pbbs>(measured, x, convert_to_pbbs);
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    deepsea::cmdline::dispatcher d;
    d.add("array_point2d", [&] {
      auto conv = [&] (parray<sptl::_point2d<double>>& x) {
        parray<pbbs::_point2d<double>> y(x.size(), [&] (intT i) {
            return pbbs::_point2d<double>(x[i].x, x[i].y);
          });
        return y;
      };
      benchmark<sptl::_point2d<double>, pbbs::_point2d<double>, decltype(conv)>(measured, conv);
    });
    d.add("array_point3d", [&]  {
      auto conv = [&] (parray<sptl::_point3d<double>>& x) {
        parray<pbbs::_point3d<double>> y(x.size(), [&] (intT i) {
            return pbbs::_point3d<double>(x[i].x, x[i].y, x[i].z);
          });
        return y;
      };
      benchmark<sptl::_point3d<double>, pbbs::_point3d<double>, decltype(conv)>(measured, conv);
    });
    d.dispatch("type");
  });
}
