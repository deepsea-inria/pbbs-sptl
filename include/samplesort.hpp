// This code is part of the Problem Based Benchmark Suite (PBBS)
// Copyright (c) 2010 Guy Blelloch and Harsha Vardhan Simhadri and the PBBS team
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

#include <iostream>
#include <algorithm>
#include <math.h>

#include "utils.hpp"
#include "quicksort.hpp"
#include "transpose.hpp"
#include "sprandgen.hpp"
#include "spparray.hpp"

#ifndef _PBBS_SPTL_SAMPLESORT_H_
#define _PBBS_SPTL_SAMPLESORT_H_

namespace sptl {
  
template<class E, class BinPred, class intT>
void split_positions(E* a, E* b, intT* c, intT length_a, intT length_b, BinPred compare) {
  if (length_a == 0 || length_b == 0) {
    return;
  }
  int pos_a = 0;
  int pos_b = 0;
  int pos_c = 0;
  for (intT i = 0; i < 2 * length_b; i++) {
    c[i] = 0;
  }
  while (pos_b < length_b) {
    while (pos_a < length_a && compare(a[pos_a], b[pos_b])) {
      c[pos_c]++;
      pos_a++;
    }
    pos_c++;
    while (pos_a < length_a && (compare(a[pos_a], b[pos_b]) ^ compare(b[pos_b], a[pos_a]) ^ true)) {
      c[pos_c]++;
      pos_a++;
    }

    pos_b++;
    pos_c++;
    // The pivots are equal
    while (pos_b < length_b && !compare(b[pos_b - 1], b[pos_b])) {
      pos_b++;
      pos_c += 2;
    }
  }
  c[pos_c] = length_a - pos_a;
}

#define SSORT_THR 100000
#define AVG_SEG_SIZE 2
#define PIVOT_QUOT 2

template<class E, class BinPred, class intT>
void sample_sort (E* a, intT n, BinPred compare) {
  if (n <= SSORT_THR) {
    quick_sort(a, n, compare);
    return;
  }
  intT sq = (intT) sqrt(n);
  intT row_length = sq * AVG_SEG_SIZE;
  intT rows = (intT) ceil(1. * n / row_length);
  // number of pivots + 1
  intT segments = (sq - 1) / PIVOT_QUOT;
  if (segments <= 1) {
    std::sort(a, a + n, compare);
    return;
  }
  int over_sample = 4;
  intT sample_set_size = segments * over_sample;
  // generate samples with oversampling
  parray<E> sample_set(sample_set_size, [&] (intT j) {
    intT o = hashi(j) % n;
    return a[o];
  });
  // sort the samples
  quick_sort(sample_set.begin(), sample_set_size, compare);
  // subselect samples at even stride
  int pivots_size = segments - 1;
  parray<E> pivots(segments - 1, [&] (intT k) {
    intT o = over_sample * k;
    return sample_set[o];
  });
  sample_set.clear();
  segments = 2 * segments - 1;
  parray<E> b;
  b.reset(rows * row_length);
  parray<intT> segments_sizes;
  segments_sizes.reset(rows * segments);
  parray<intT> offset_a;
  offset_a.reset(rows * segments);
  parray<intT> offset_b;
  offset_b.reset(rows * segments);
  // sort each row and merge with samples to get counts
  parallel_for((intT)0, rows, [&] (intT lo, intT hi) { return (hi - lo) * row_length; }, [&] (intT r) {
    intT offset = r * row_length;
    intT size = (r < rows - 1) ? row_length : n - offset;
    sample_sort(a + offset, size, compare);
    split_positions(a + offset, pivots.begin(), segments_sizes.begin() + r * segments, size, (intT)pivots.size(), compare);
  });
  // transpose from rows to columns
  auto plus = [&] (intT x, intT y) {
    return x + y;
  };
  dps::scan(segments_sizes.begin(), segments_sizes.end(), (intT)0, plus, offset_a.begin(), forward_exclusive_scan);
  transpose(segments_sizes.begin(), offset_b.begin(), rows, segments);
  dps::scan(offset_b.begin(), offset_b.end(), (intT)0, plus, offset_b.begin(), forward_exclusive_scan);
  block_transpose(a, b.begin(), offset_a.begin(), offset_b.begin(), segments_sizes.begin(), rows, segments);
  sptl::copy(b.begin(), b.begin() + n, a);
  // sort the columns
  parray<intT> complexities(pivots_size + 1, [&] (int i) {
    double s = (i == 0 || i == pivots_size || compare(pivots[i - 1], pivots[i])) ?
               (i == pivots_size ? n : offset_b[(2 * i + 1) * rows]) - offset_b[2 * i * rows] :
               1;
    return s * (log(s) + 1);
  });
  dps::scan(complexities.begin(), complexities.end(), (intT)0, plus, complexities.begin(), forward_inclusive_scan);
  auto complexity_fct = [&] (intT lo, intT hi) {
    if (lo == hi) {
      return 0;
    } else if (lo == 0) {
      return complexities[hi - 1];
    } else {
      return complexities[hi - 1] - complexities[lo - 1];
    }
  };
  b.clear();
  offset_a.clear();
  segments_sizes.clear();
  parallel_for((intT)0, (intT)(pivots_size + 1), complexity_fct, [&] (intT i) {
    intT offset = offset_b[(2 * i) * rows];
    if (i == 0) {
      sample_sort(a, offset_b[rows], compare); // first segment
    } else if (i < pivots_size) { // middle segments
      if (compare(pivots[i - 1], pivots[i])) {
        sample_sort(a + offset, offset_b[(2 * i + 1) * rows] - offset, compare);
      }
    } else { // last segment
      sample_sort(a + offset, n - offset, compare);
    }
  });
}

} // end namespace

#define comparison_sort(__A, __n, __f) (sample_sort(__A, __n, __f))

#endif /*! _PBBS_PCTL_SAMPLESORT_H_ !*/
