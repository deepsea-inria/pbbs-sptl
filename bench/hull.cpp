
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
  std::string lib_type = deepsea::cmdline::parse_or_default_string("lib_type", "pctl");
  if (lib_type == "pbbs") {
    parray<pbbs::_point2d<double>> y = to_pbbs(x);
    measured([&] {
      pbbs::hull(&y[0], (int)y.size());
    });
  } else {
    measured([&] {
      sptl::hull(x);
    });
  }
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
    if (infile == "") {
      sptl::die("bogus infile");
    }
    parray<sptl::_point2d<double>> x = sptl::read_from_file<parray<sptl::_point2d<double>>>(infile);
    pbbs_sptl_call(measured, x);
  });
}
