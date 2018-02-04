
#include "geometry.hpp"
#include "spdataparallel.hpp"

namespace sptl {
  using intT = int;
  typedef _point3d<double> pointT;

  intT* ray_cast(triangles<pointT>, ray<pointT>*, intT);
}


