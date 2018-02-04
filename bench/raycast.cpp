
#include <math.h>
#include <functional>
#include <stdlib.h>
#include <algorithm>

#include "bench.hpp"

#include "kdtree.hpp"
#include "kdTree.h"

template <class Item>
using parray = sptl::parray<Item>;

pbbs::_point3d<double> to_pbbs(sptl::_point3d<double> point) {
  return pbbs::_point3d<double>(point.x, point.y, point.z);
}

pbbs::_vect3d<double> to_pbbs(sptl::_vect3d<double> vect) {
  return pbbs::_vect3d<double>(vect.x, vect.y, vect.z);
}

pbbs::triangle to_pbbs(sptl::triangle t) {
  return pbbs::triangle(t.vertices[0], t.vertices[1], t.vertices[2]);
}

pbbs::ray<pbbs::_point3d<double>> to_pbbs(sptl::ray<sptl::_point3d<double>> ray) {
  return pbbs::ray<pbbs::_point3d<double>>(to_pbbs(ray.o), to_pbbs(ray.d));
}

template <class Item1, class Item2>
parray<Item1> to_pbbs(parray<Item2>& a) {
  parray<Item1> result(a.size(), [&] (int i) {
    return to_pbbs(a[i]);
  });
  return result;
}

void benchmark(sptl::bench::measured_type measured) {
  std::string infile = deepsea::cmdline::parse_or_default_string("infile", "");
  if (infile == "") {
    sptl::die("bogus infile");
  }
  sptl::ray_cast_test x = sptl::read_from_file<sptl::ray_cast_test>(infile);
  bool should_check = deepsea::cmdline::parse_or_default_bool("check", false);
  parray<intT> sptl_result;
  intT* pbbs_result = nullptr;
  auto do_pbbs = [&] {
    parray<pbbs::_point3d<double>> points = to_pbbs<pbbs::_point3d<double>>(x.points);
    parray<pbbs::triangle> triangles = to_pbbs<pbbs::triangle>(x.triangles);
    parray<pbbs::ray<pbbs::_point3d<double>>> rays = to_pbbs<pbbs::ray<pbbs::_point3d<double>>>(x.rays);
    pbbs::triangles<pbbs::_point3d<double>> tri(points.size(), triangles.size(), points.begin(), triangles.begin());
    measured([&] {
      pbbs_result = pbbs::rayCast(tri, rays.begin(), rays.size());
    });
  };
  deepsea::cmdline::dispatcher d;
  d.add("pbbs", do_pbbs);
  d.add("sptl", [&] {
    sptl::triangles<sptl::_point3d<double>> tri(x.points.size(), x.triangles.size(), x.points.begin(), x.triangles.begin());
    measured([&] {
      sptl_result = sptl::kdtree::ray_cast(tri, x.rays.begin(), x.rays.size());
    });
    if (should_check) {
      do_pbbs();
      for (intT i = 0; i < sptl_result.size(); i++) {
        if (sptl_result[i] != pbbs_result[i]) {
          sptl::die("bogus result at index %d\n", i);
        }
      }
    }
  });
  if (pbbs_result != nullptr) {
    free(pbbs_result);
  }
  d.dispatch("library");
}

int main(int argc, char** argv) {
  sptl::bench::launch(argc, argv, [&] (sptl::bench::measured_type measured) {
    benchmark(measured);
  });
}
