// This code is part of the Problem Based Benchmark Suite (PBBS)
// Copyright (c) 2011 Guy Blelloch and the PBBS team
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights (to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#include <chrono>
#include <float.h>

#include "geometry.hpp"
#include "spdataparallel.hpp"
#include "raytriangleintersect.hpp"
#include "samplesort.hpp"
#include "ray.hpp"

#ifndef _SPTL_KDTREE_H_
#define _SPTL_KDTREE_H_

namespace sptl {
namespace kdtree {

// Stores coordinate of event along with index to its triangle and type
// Stores type of event (START or END) in lowest bit of index
struct event {
  float v;
  intT p;
  event(float value, intT index, bool type)
  : v(value), p((index << 1) + type) {}
  event() {}
};
#define START 0
#define IS_START(_event) (!(_event.p & 1))
#define END 1
#define IS_END(_event) ((_event.p & 1))
#define GET_INDEX(_event) (_event.p >> 1)

struct cmpVal { bool operator() (event a, event b) {return a.v < b.v || (a.v == b.v && GET_INDEX(a) < GET_INDEX(b));}};

struct range {
  float min;
  float max;
  range(float _min, float _max) : min(_min), max(_max) {}
  range() {}
};

typedef range* boxes[3];
typedef parray<event> events[3];
typedef range bounding_box[3];

static std::ostream& operator<<(std::ostream& os, const bounding_box b) {
  return os << b[0].min << ":" << b[0].max << " + "
  << b[1].min << ":" << b[1].max << " + "
  << b[2].min << ":" << b[2].max;
}

struct cut_info {
  float cost;
  float cut_off;
  intT num_left;
  intT num_right;
  cut_info(float _cost, float _cut_off, intT nl, intT nr)
  : cost(_cost), cut_off(_cut_off), num_left(nl), num_right(nr) {}
  cut_info() {}
};

struct tree_node {
  tree_node *left;
  tree_node *right;
  bounding_box box;
  int cut_dim;
  float cut_off;
  intT* triangle_indices;
  intT n;
  intT leaves;
  
  bool is_leaf() {
    return (triangle_indices != NULL);
  }
  
  tree_node(tree_node* L, tree_node* R,
           int _cut_dim, float _cut_off, bounding_box B)
  : left(L), right(R), triangle_indices(NULL), cut_dim(_cut_dim),
    cut_off(_cut_off) {
    for (int i = 0; i < 3; i++) {
      box[i] = B[i];
    }
    n = L->n + R->n;
    leaves = L->leaves + R->leaves;
  }
  
  tree_node(events& E, intT _n, bounding_box B)
  : left(NULL), right(NULL) {
    
    event* events = E[0].begin();
    
    // extract indices from events
    triangle_indices = newA(intT, _n/2);
    intT k = 0;
    for (intT i = 0; i < _n; i++) {
      if (IS_START(events[i])) {
        triangle_indices[k++] = GET_INDEX(events[i]);
      }
    }
    
    n = _n / 2;
    leaves = 1;
    for (int i = 0; i < 3; i++) {
      box[i] = B[i];E[i].clear();
//      free(E[i]);
    }
  }
  
  static void del(tree_node* t) {
    spguard([&] { return t->n; }, [&] {
      if (t->is_leaf()) {
        free(t->triangle_indices);
      } else {
        fork2([&] {
          del(t->left);
        }, [&] {
          del(t->right);
        });
      }
      delete t;
    });
  }
};

using namespace std;

int CHECK12 = 0;  // if set checks 10 rays against brute force method
int STATS = 0;  // if set prints out some tree statistics

// Constants for deciding when to stop recursion in building the KDTree
float CT = 6.0;
float CL = 1.25;
float max_expand = 1.6;
int max_recursion_depth = 25;
int min_parallel_size = 500000;
// Constant for switching to sequential versions

typedef pointT::floatT floatT;
typedef _vect3d<floatT> vectT;
typedef triangles<pointT> trianglesT;
typedef ray<pointT> rayT;

float box_surface_area(bounding_box b) {
  float r0 = b[0].max - b[0].min;
  float r1 = b[1].max - b[1].min;
  float r2 = b[2].max - b[2].min;
  return 2 * (r0 * r1 + r1 * r2 + r0 * r2);
}

float epsilon = .0000001;
range fix_range(float minv, float maxv) {
  if (minv == maxv) {
    return range(minv, minv + epsilon);
  } else {
    return range(minv, maxv);
  }
}

inline float in_box(pointT p, bounding_box b) {
  return (p.x >= (b[0].min - epsilon) && p.x <= (b[0].max + epsilon) &&
          p.y >= (b[1].min - epsilon) && p.y <= (b[1].max + epsilon) &&
          p.z >= (b[2].min - epsilon) && p.z <= (b[2].max + epsilon));
}

// sequential version of best cut
cut_info best_cut_serial(event* e, range r, range r1, range r2, intT n) {
  if (r.max - r.min == 0.0) {
    return cut_info(FLT_MAX, r.min, n, n);
  }
  float area = 2 * (r1.max - r1.min) * (r2.max - r2.min);
  float diameter = 2 * ((r1.max - r1.min) + (r2.max - r2.min));
  
  // calculate cost of each possible split
  intT in_left = 0;
  intT in_right = n / 2;
  float min_cost = FLT_MAX;
  intT k = 0;
  intT rn = in_left;
  intT ln = in_right;
  for (intT i = 0; i < n; i++) {
    float cost;
    if (IS_END(e[i])) in_right--;
    float left_length = e[i].v - r.min;
    float left_area = area + diameter * left_length;
    float right_length = r.max - e[i].v;
    float right_area = area + diameter * right_length;
    cost = (left_area * in_left + right_area * in_right);
    if (cost < min_cost) {
      rn = in_right;
      ln = in_left;
      min_cost = cost;
      k = i;
    }
    if (IS_START(e[i])) in_left++;
  }

  return cut_info(min_cost, e[k].v, ln, rn);
}

// parallel version of best cut
cut_info best_cut(event* e, range r, range r1, range r2, intT n) {
  cut_info result;
  
  spguard([&] { return 5 * n; }, /*[&] { return n; }, */ [&, e] {
    if (r.max - r.min == 0.0) {
      result = cut_info(FLT_MAX, r.min, n, n);
      return result;
    }
    
    // area of two orthogonal faces
    float orthog_area = 2 * ((r1.max - r1.min) * (r2.max - r2.min));
    
    // length of diameter of orthogonal face
    float diameter = 2 * ((r1.max - r1.min) + (r2.max - r2.min));
    
    // count number that end before i
    parray<intT> upper;
    upper.reset(n);
    intT* upper_ptr = upper.begin();
    parallel_for(0, n, [&] (intT l, intT r) { return r - l; }, [&] (intT i) {
      upper_ptr[i] = IS_END(e[i]);
    }, [&, e, upper_ptr] (intT l, intT r) {
      for (int i = l; i < r; i++) {
        upper_ptr[i] = IS_END(e[i]);
      }
    });
    intT u = dps::scan(upper.begin(), upper.end(), (intT)0, [&] (intT x, intT y) {
      return x + y; }, upper.begin(), forward_exclusive_scan
    );
    // calculate cost of each possible split location
    parray<float> cost;
    cost.reset(n);
    float* cost_ptr = cost.begin();

    parallel_for(0, n, [&] (intT l, intT r) { return r - l; }, [&, e, cost_ptr, upper_ptr] (intT i) {
      intT in_left = i - upper_ptr[i];
      intT in_right = n / 2 - (upper_ptr[i] + IS_END(e[i]));
      float left_length = e[i].v - r.min;
      float left_area = orthog_area + diameter * left_length;
      float right_length = r.max - e[i].v;
      float right_area = orthog_area + diameter * right_length;
      cost_ptr[i] = left_area * in_left + right_area * in_right;
    }, [&, e, cost_ptr, upper_ptr] (intT ll, intT rr) {
      for (intT i = ll; i < rr; i++) {
        intT in_left = i - upper_ptr[i];
        intT in_right = n / 2 - (upper_ptr[i] + IS_END(e[i]));
        float left_length = e[i].v - r.min;
        float left_area = orthog_area + diameter * left_length;
        float right_length = r.max - e[i].v;
        float right_area = orthog_area + diameter * right_length;
        cost_ptr[i] = left_area * in_left + right_area * in_right;
      }
    });
    
    // find minimum across all (maxIndex with less is minimum)
    intT k = (intT)max_index(cost.cbegin(), cost.cend(), cost[0], [&] (float x, float y) {
      return x < y;
    });
      
    float c = cost_ptr[k];
    intT ln = k - upper_ptr[k];
    intT rn = n / 2 - (upper_ptr[k] + IS_END(e[k]));
    result = cut_info(c, e[k].v, ln, rn);
  }, [&] {
    result = best_cut_serial(e, r, r1, r2, n);
  });
  return result;
}

std::pair<intT, intT> split_events_serial(range* boxes, event* events,
                       float cut_off, intT n,
                       parray<event>& left, parray<event>& right) {
  intT l = 0;
  intT r = 0;

  left.reset(n);
  right.reset(n);
  event* left_ptr = left.begin();
  event* right_ptr = right.begin();

  for (intT i = 0; i < n; i++) {
    intT b = GET_INDEX(events[i]);
    if (boxes[b].min < cut_off) {
      left_ptr[l++] = events[i];
      if (boxes[b].max > cut_off) {
        right_ptr[r++] = events[i];
      }
    } else {
      right_ptr[r++] = events[i];
    }
  }
  return make_pair(l, r);
}

std::pair<intT, intT> split_events(range* boxes, event* events, float cut_off, intT n,
                 parray<event>& left, parray<event>& right) {
  std::pair<intT, intT> result;
  
  spguard([&] { return 5 * n; }, /*[&] { return n; },*/ [&, boxes, events] {
    parray<bool> lower;
    lower.reset(n);
    bool* lower_ptr = lower.begin();
    parray<bool> upper;
    upper.reset(n);
    bool* upper_ptr = upper.begin();

    parallel_for(0, n, [&] (intT l, intT r) { return r - l; }, [&, events, boxes, lower_ptr, upper_ptr] (intT i) {
      intT b = GET_INDEX(events[i]);
      lower_ptr[i] = boxes[b].min < cut_off;
      upper_ptr[i] = boxes[b].max > cut_off || boxes[b].min >= cut_off;
    }, [&, events, boxes, lower_ptr, upper_ptr] (intT l, intT r) {
      for (intT i = l; i < r; i++) {
        intT b = GET_INDEX(events[i]);
        lower_ptr[i] = boxes[b].min < cut_off;
        upper_ptr[i] = boxes[b].max > cut_off || boxes[b].min >= cut_off;
      }
    });
    const event* events2 = (const event*)events;

    left = sptl::pack(events2, events2 + n, lower_ptr);
    right = sptl::pack(events2, events2 + n, upper_ptr);
    result = make_pair(left.size(), right.size());

  }, [&] {
    result = split_events_serial(boxes, events, cut_off, n, left, right);
  });

  return result;
}
  
// n is the number of events (i.e. twice the number of triangles)
tree_node* generate_node(boxes bxs, events& evts, bounding_box b,
                       intT n, intT max_depth) {
  
  tree_node* result;
  //  spguard([&] { return n; }, [&] {
    if (n <= 2 || max_depth == 0) {
      result = new tree_node(evts, n, b);
      return result;
    }

    // loop over dimensions and find the best cut across all of them
    cut_info cuts[3];
    parallel_for(0, 3, [&] (int l, int r) { return (r - l) * n; }, [&] (int d) {
      cuts[d] = best_cut(evts[d].begin(), b[d], b[(d + 1) % 3], b[(d + 2) % 3], n);
    });
    
    int cut_dim = 0;
    for (int d = 1; d < 3; d++) {
      if (cuts[d].cost < cuts[cut_dim].cost) {
        cut_dim = d;
      }
    }
    
    range* cut_dim_ranges = bxs[cut_dim];
    float cut_off = cuts[cut_dim].cut_off;
    float area = box_surface_area(b);
    float best_cost = CT + CL * cuts[cut_dim].cost / area;
    float orig_cost = (float) (n / 2);
    // quit recursion early if best cut is not very good
    if (best_cost >= orig_cost ||
        cuts[cut_dim].num_left + cuts[cut_dim].num_right > max_expand * n / 2) {
      result = new tree_node(evts, n, b);
      return result;
    }
    
    // declare structures for recursive calls
    bounding_box bbl;
    for (int i = 0; i < 3; i++) {
      bbl[i] = b[i];
    }
    bbl[cut_dim] = range(bbl[cut_dim].min, cut_off);
    intT nl;
    
    bounding_box bbr;
    for (int i = 0; i < 3; i++) {
      bbr[i] = b[i];
    }
    bbr[cut_dim] = range(cut_off, bbr[cut_dim].max);
    intT nr;

    // now split each event array to the two sides
    events xl;
    events xr;
    std::pair<intT, intT> sizes[3];
    parallel_for(0, 3, [&] (int l, int r) { return (r - l) * n; }, [&] (int d) {
      sizes[d] = split_events(cut_dim_ranges, evts[d].begin(), cut_off, n, xl[d], xr[d]);
    });
    
    for (int d = 0; d < 3; d++) {
      if (d == 0) {
        nl = sizes[d].first;
        nr = sizes[d].second;
      } else if (sizes[d].first != nl || sizes[d].second != nr) {
        cout << "kdTree: mismatched lengths, something wrong" << endl;
        abort();
      }
    }
    
    // free old events and make recursive calls
    for (int i = 0; i < 3; i++) {
      evts[i].clear();
    }
    tree_node* l;
    tree_node* r;
    fork2([&] {
      l = generate_node(bxs, xl, bbl, nl, max_depth - 1);
    }, [&] {
      r = generate_node(bxs, xr, bbr, nr, max_depth - 1);
    });
    result = new tree_node(l, r, cut_dim, cut_off, b);
    //  });
  return result;
}

intT tcount = 0;
intT ccount = 0;

// Given an a ray, a bounding box, and a sequence of triangles, returns the
// index of the first triangle the ray intersects inside the box.
// The triangles are given by n indices I into the triangle array tri.
// -1 is returned if there is no intersection
intT find_ray(rayT r, intT* indices, intT n, triangles<pointT> tri, bounding_box b) {
  if (STATS) {
    tcount += n;
    ccount += 1;
  }
  pointT* p = tri.p;
  floatT min_t = FLT_MAX;
  intT k = -1;
  for (intT i = 0; i < n; i++) {
    intT j = indices[i];
    triangle* tr = tri.t + j;
    pointT m[3] = { p[tr->vertices[0]], p[tr->vertices[1]], p[tr->vertices[2]] };
    floatT t = ray_triangle_intersect(r, m);
    if (t > 0.0 && t < min_t && in_box(r.o + r.d * t, b)) {
      min_t = t;
      k = j;
    }
  }
  return k;
}

// Given a ray and a tree node find the index of the first triangle the
// ray intersects inside the box represented by that node.
// -1 is returned if there is no intersection
intT find_ray(rayT r, tree_node* tree, trianglesT tri) {
  //cout << "tree->n=" << tree->n << endl;
  if (tree->is_leaf()) {
    return find_ray(r, tree->triangle_indices, tree->n, tri, tree->box);
  }
  pointT o = r.o;
  vectT d = r.d;
  
  floatT oo[3] = { o.x, o.y, o.z };
  floatT dd[3] = { d.x, d.y, d.z };
  
  // intersect ray with splitting plane
  int k0 = tree->cut_dim;
  int k1 = (k0 == 2) ? 0 : k0 + 1;
  int k2 = (k0 == 0) ? 2 : k0 - 1;
  point2d o_p(oo[k1], oo[k2]);
  vect2d d_p(dd[k1], dd[k2]);
  // does not yet deal with dd[k0] == 0
  floatT scale = (tree->cut_off - oo[k0]) / dd[k0];
  point2d p_i = o_p + d_p * scale;
  
  range rx = tree->box[k1];
  range ry = tree->box[k2];
  floatT d_0 = dd[k0];
  
  // decide which of the two child boxes the ray intersects
  enum { LEFT, RIGHT, BOTH };
  int recurse_to = LEFT;
  if      (p_i.x < rx.min) { if (d_p.x * d_0 > 0) recurse_to = RIGHT;}
  else if (p_i.x > rx.max) { if (d_p.x * d_0 < 0) recurse_to = RIGHT;}
  else if (p_i.y < ry.min) { if (d_p.y * d_0 > 0) recurse_to = RIGHT;}
  else if (p_i.y > ry.max) { if (d_p.y * d_0 < 0) recurse_to = RIGHT;}
  else recurse_to = BOTH;
  
  if (recurse_to == RIGHT) {
    return find_ray(r, tree->right, tri);
  } else if (recurse_to == LEFT) {
    return find_ray(r, tree->left, tri);
  } else if (d_0 > 0) {
    intT t = find_ray(r, tree->left, tri);
    if (t >= 0) {
      return t;
    } else {
      return find_ray(r, tree->right, tri);
    }
  } else {
    intT t = find_ray(r, tree->right, tri);
    if (t >= 0) {
      return t;
    } else {
      return find_ray(r, tree->left, tri);
    }
  }
}

void process_rays(trianglesT tri, rayT* rays, intT num_rays,
                 tree_node* tree, intT* results) {
  parallel_for((intT)0, num_rays, [&] (intT l, intT r) { return r - l; }, [&] (intT i) {
    results[i] = find_ray(rays[i], tree, tri);
  }, [&, rays, results, tree] (intT l, intT r) {
    for (int i = l; i < r; i++) {
      results[i] = find_ray(rays[i], tree, tri);
    }
  });
}

parray<intT> ray_cast(triangles<pointT> tri, ray<pointT>* rays, int num_rays) {
  
  // Extract triangles into a separate array for each dimension with
  // the lower and upper bound for each triangle in that dimension.
  boxes bxs;
  intT n = tri.num_triangles;
  for (int d = 0; d < 3; d++) {
    bxs[d] = newA(range, n);
  }
  pointT* p = tri.p;
  triangle* t = tri.t;
  parallel_for((intT)0, n, [&] (intT l, intT r) { return r - l; }, [&, p, t, bxs] (intT i) {
    pointT p0 = p[t[i].vertices[0]];
    pointT p1 = p[t[i].vertices[1]];
    pointT p2 = p[t[i].vertices[2]];
    bxs[0][i] = fix_range(std::min(p0.x, std::min(p1.x, p2.x)), std::max(p0.x, std::max(p1.x, p2.x)));
    bxs[1][i] = fix_range(std::min(p0.y, std::min(p1.y, p2.y)), std::max(p0.y, std::max(p1.y, p2.y)));
    bxs[2][i] = fix_range(std::min(p0.z, std::min(p1.z, p2.z)), std::max(p0.z, std::max(p1.z, p2.z)));
  }, [&, p, t, bxs] (intT l, intT r) {
    for (intT i = l; i < r; i++) {
      pointT p0 = p[t[i].vertices[0]];
      pointT p1 = p[t[i].vertices[1]];
      pointT p2 = p[t[i].vertices[2]];
      bxs[0][i] = fix_range(std::min(p0.x, std::min(p1.x, p2.x)), std::max(p0.x, std::max(p1.x, p2.x)));
      bxs[1][i] = fix_range(std::min(p0.y, std::min(p1.y, p2.y)), std::max(p0.y, std::max(p1.y, p2.y)));
      bxs[2][i] = fix_range(std::min(p0.z, std::min(p1.z, p2.z)), std::max(p0.z, std::max(p1.z, p2.z)));
    }
  });
  // Loop over the dimensions creating an array of events for each
  // dimension, sorting each one, and extracting the bounding box
  // from the first and last elements in the sorted events in each dim.
  events evts;
  events tmp_evts;
  bounding_box box;
  for (int d = 0; d < 3; d++) {
    evts[d].reset(2 * n);
    event* evts_ptr = evts[d].begin();
    range* cur_box = bxs[d];
    parallel_for((intT)0, n, [&] (int l, int r) { return r - l; }, [&] (intT i) {
      evts_ptr[2 * i] = event(cur_box[i].min, i, START);
      evts_ptr[2 * i + 1] = event(cur_box[i].max, i, END);
    }, [&, cur_box, evts_ptr] (intT l, intT r) {
      for (int i = l; i < r; i++) {
        evts_ptr[2 * i] = event(cur_box[i].min, i, START);
        evts_ptr[2 * i + 1] = event(cur_box[i].max, i, END);
      }
    });
    sample_sort(evts_ptr, 2 * n, cmpVal());
//    quick_sort(evts[d], 2 * n, cmpVal());
//    std::sort(evts[d], evts[d] + 2 * n, cmpVal());
    box[d] = range(evts_ptr[0].v, evts_ptr[2 * n - 1].v);
  }
  
  // build the tree
  intT recursion_depth = std::min(max_recursion_depth, utils::log2Up(n) - 1);
//  std::cerr << "Depth: " << recursion_depth << std::endl;
  tree_node* tree = generate_node(bxs, evts, box, 2 * n,
                             recursion_depth);
  
  if (STATS)
    cout << "Triangles across all leaves = " << tree->n 
    << " Leaves = " << tree->leaves << endl;
  for (int d = 0; d < 3; d++) {
    free(bxs[d]);
//    free(evts[d]);
//    free(tmp_evts[d]);
  }
  
  // get the intersections
  parray<intT> results;
  results.reset(num_rays);
  process_rays(tri, rays, num_rays, tree, results.begin());


  tree_node::del(tree);
  
  if (CHECK12) {
    int nr = 10;
    parray<intT> indx(n, [&] (intT i) {
      return i;
    });
    for (int i= 0; i < nr; i++) {
      cout << results[i] << endl;
      if (find_ray(rays[i], indx.begin(), n, tri, box) != results[i]) {
        cout << "bad intersect in checking ray intersection" << endl;
        abort();
      }
    }
  }
  
  if (STATS)
    cout << "tcount=" << tcount << " ccount=" << ccount << endl;
  return results;
}
  
parray<intT> ray_cast_seq(triangles<pointT> tri, ray<pointT>* rays, int num_rays) {
  bounding_box box;
  for (int i = 0; i < 3; i++) {
    box[i] = range(-std::numeric_limits<double>::max(), std::numeric_limits<double>::max());
  }

  parray<intT> indices(tri.num_triangles, [&] (int i) { return i; });
  parray<intT> result;
  result.reset(num_rays);
  for (int i = 0; i < num_rays; i++) {
    result[i] = find_ray(rays[i], indices.begin(), indices.size(), tri, box);
  }
  return result;
}
  
} // end namespace
} // end namespace


#endif
