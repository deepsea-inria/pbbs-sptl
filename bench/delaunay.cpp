
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "delaunay.hpp"
#include "delaunay.h"

template <class Item>
using parray = sptl::parray<Item>;

void benchmark(sptl::bench::measured_type measured) {
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  if (infile == "") {
    sptl::die("bogus infile");
  }
  parray<sptl::_point2d<double>> x = sptl::read_from_file<parray<sptl::_point2d<double>>>(infile);
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  sptl::triangles<sptl::point2d> sptl_result;
  pbbs::triangles<pbbs::point2d> pbbs_result;
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", [&] {
    parray<pbbs::_point2d<double>> y(x.size(), [&] (int i) {
      return pbbs::_point2d<double>(x[i].x, x[i].y);
    });
    measured([&] {
      pbbs_result = pbbs::delaunay(&y[0], (int)y.size());
    });
  });
  d.add("sptl", [&] {
    measured([&] {
      sptl_result = sptl::delaunay(x);
    });
    if (should_check) {
      // todo
    }
  });
  d.dispatch("library");
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    benchmark(measured);
  });
}
