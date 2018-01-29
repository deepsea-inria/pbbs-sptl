
#include <math.h>
#include <functional>
#include <stdlib.h>

#include "hull.hpp"
#include "bench.hpp"

#include "hull.h"

template <class Item>
using parray = sptl::parray<Item>;

parray<pbbs::_point2d<double>> to_pbbs(parray<sptl::_point2d<double>>& points) {
  parray<pbbs::_point2d<double>> result(points.size());
  for (int i = 0; i < points.size(); i++) {
    result[i] = pbbs::_point2d<double>(points[i].x, points[i].y);
  }
  return result;
}

void pbbs_sptl_call(sptl::bench::measured_type measured, parray<sptl::_point2d<double>>& x) {
  deepsea::cmdline::dispatcher d;
  pbbs::_seq<intT> pbbs_result;
  auto do_pbbs = [&] {
    parray<pbbs::_point2d<double>> y = to_pbbs(x);
    measured([&] {
      pbbs_result = pbbs::hull(&y[0], (int)y.size());
    });
  };
  d.add("pbbs", do_pbbs);
  d.add("pctl", [&] {
    parray<intT> sptl_result;
    measured([&] {
      sptl_result = sptl::hull(x);
    });
    if (deepsea::cmdline::parse_or_default_bool("check", false)) {
      do_pbbs();
      if (pbbs_result.n != sptl_result.size()) {
        sptl::die("bogus size");
      }
      for (size_t i = 0; i < sptl_result.size(); i++) {
        if (sptl_result[i] != pbbs_result.A[i]) {
          sptl::die("bogus item at position %d", i);
        }
      }
    }
  });
  d.dispatch("library");
  pbbs_result.del();
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
    if (infile == "") {
      sptl::die("missing infile");
    }
    parray<sptl::_point2d<double>> x = sptl::read_from_file<parray<sptl::_point2d<double>>>(infile);
    pbbs_sptl_call(measured, x);
  });
}
