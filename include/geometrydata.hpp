
#include "spparray.hpp"
#include "sprandgen.hpp"

#include "geometry.hpp"

#ifndef _PBBS_SPTL_GEOMETRYDATA
#define _PBBS_SPTL_GEOMETRYDATA

namespace sptl {

template <class uintT>
point2d rand2d(uintT i) {
  uintT s1 = i;
  uintT s2 = i + hash<uintT>(s1);
  return point2d(2*hash<double>(s1)-1,
                 2*hash<double>(s2)-1);
}

template <class intT, class uintT>
point3d rand3d(intT i) {
  uintT s1 = i;
  uintT s2 = i + hash<uintT>(s1);
  uintT s3 = 2*i + hash<uintT>(s2);
  return point3d(2*hash<double>(s1)-1,
                 2*hash<double>(s2)-1,
                 2*hash<double>(s3)-1);
}

template <class intT>
point2d randInUnitSphere2d(intT i) {
  intT j = 0;
  vect2d v;
  do {
    intT o = hash<intT>(j++);
    v = vect2d(rand2d(o + i));
  } while (v.length() > 1.0);
  return point2d(v);
}

template <class intT, class uintT>
point3d randInUnitSphere3d(intT i) {
  intT j = 0;
  vect3d v;
  do {
    intT o = hash<intT>(j++);
    v = vect3d(rand3d<intT, uintT>(o+i));
  } while (v.length() > 1.0);
  return point3d(v);
}

template <class intT>
point2d randOnUnitSphere2d(intT i) {
  vect2d v = vect2d(randInUnitSphere2d(i));
  return point2d(v / v.length());
}

template <class intT,class uintT>
point3d randOnUnitSphere3d(intT i) {
  vect3d v = vect3d(randInUnitSphere3d<intT, uintT>(i));
  return point3d(v / v.length());
}

template <class intT>
point2d randKuzmin(intT i) {
  vect2d v = vect2d(randOnUnitSphere2d(i));
  intT j = hash<intT>(i);
  double s = hash<double>(j);
  double r = sqrt(1.0/((1.0-s)*(1.0-s))-1.0);
  return point2d(v*r);
}

template <class intT,class uintT>
point3d randPlummer(intT i) {
  vect3d v = vect3d(randOnUnitSphere3d<intT,uintT>(i));
  intT j = hash<intT>(i);
  double s = pow(hash<double>(j),2.0/3.0);
  double r = sqrt(s/(1-s));
  return point3d(v*r);
}

template <class intT>
parray<point2d> plummer2d(intT n) {
  return parray<point2d>(n, [&] (intT i) {
    return randKuzmin(i);
  });
}

template <class intT>
parray<point2d> uniform2d(bool inSphere, bool onSphere, intT n) {
  return parray<point2d>(n, [&] (intT i) {
    if (inSphere) return randInUnitSphere2d(i);
    else if (onSphere) return randOnUnitSphere2d(i);
    else return rand2d(i);
  });
}

template <class intT, class uintT>
parray<point3d> plummer3d(intT n) {
  return parray<point3d>(n, [&] (intT i) {
    return randPlummer<intT, uintT>(i);
  });
}

template <class intT, class uintT>
parray<point3d> uniform3d(bool inSphere, bool onSphere, intT n) {
  return parray<point3d>(n, [&] (intT i) {
    if (inSphere) return randInUnitSphere3d<intT,uintT>(i);
    else if (onSphere) return randOnUnitSphere3d<intT,uintT>(i);
    else return rand3d<intT, uintT>(i);
  });
}

} // end namespace

#endif
