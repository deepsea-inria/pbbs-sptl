
#include "geometry.hpp"

// There are 3 versions in here
// The second is definitely slower than the first
// The third is broken into two parts, where the first only depends
//   on the triangle (slow) and the second adds the ray

#ifndef _PBBS_SPTL_RAYTRIANGLEINTERSECT_H_
#define _PBBS_SPTL_RAYTRIANGLEINTERSECT_H_

#define EPSILON 0.00000001

namespace sptl {
    
// Code is based on:
// Fast, Minimum Storage Ray/Triangle Intersection
// Tomas Moller and Ben Trumbore
template <class floatT>
inline floatT ray_triangle_intersect(ray<_point3d<floatT> > R,
                                   _point3d<floatT> m[]) {
  typedef _point3d<floatT> pointT;
  typedef _vect3d<floatT> vectT;
  pointT o = R.o;
  vectT d = R.d;
  vectT e1 = m[1] - m[0];
  vectT e2 = m[2] - m[0];
  
  vectT pvec = d.cross(e2);
  floatT det = e1.dot(pvec);
  
  // if determinant is zero then ray is
  // parallel with the triangle plane
  if (det > -EPSILON && det < EPSILON) return 0;
  floatT det_inverse = 1.0 / det;
  
  // calculate distance from m[0] to origin
  vectT tvec = o - m[0];
  
  // u and v are the barycentric coordinates
  // in triangle if u >= 0, v >= 0 and u + v <= 1
  floatT u = tvec.dot(pvec) * det_inverse;
  
  // check against one edge and opposite point
  if (u < 0.0 || u > 1.0) return 0;
  
  vectT qvec = tvec.cross(e1);
  floatT v = d.dot(qvec) * det_inverse;
  
  // check against other edges
  if (v < 0.0 || u + v > 1.0) return 0;
  
  //distance along the ray, i.e. intersect at o + t * d
  floatT t = e2.dot(qvec) * det_inverse;
  
  return t;
}
  

} // end namespace

#endif
