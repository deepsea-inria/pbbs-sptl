
#include "spdataparallel.hpp"

#ifndef _PBBS_SPTL_TRANSPOSE
#define _PBBS_SPTL_TRANSPOSE

namespace sptl {

template <class E, class intT>
void transpose(E* A, E* B,
               intT rStart, intT rCount, intT rLength,
               intT cStart, intT cCount, intT cLength) {

  auto seq = [&] {
    for (intT i=rStart; i < rStart + rCount; i++)
      for (intT j=cStart; j < cStart + cCount; j++)
        B[j*cLength + i] = A[i*rLength + j];
  };
  spguard( [&] { return rCount * cCount; }, [&] {
    if (cCount < 2 && rCount < 2) {
      seq();
    } else if (cCount > rCount) {
      intT l1 = cCount/2;
      intT l2 = cCount - cCount/2;
      fork2([&] { transpose(A, B, rStart,rCount,rLength,cStart,l1,cLength); },
            [&] { transpose(A, B, rStart,rCount,rLength,cStart + l1,l2,cLength); });
    } else {
      intT l1 = rCount/2;
      intT l2 = rCount - rCount/2;
      fork2([&] { transpose(A, B, rStart,l1,rLength,cStart,cCount,cLength); },
            [&] { transpose(A, B, rStart + l1,l2,rLength,cStart,cCount,cLength); });
    }
    
  }, seq);
}

template <class E, class intT>
void transpose(E* A, E* B, intT rCount, intT cCount) {
  transpose(A, B, 0,rCount,cCount,0,cCount,rCount);
}

  
template <class E, class intT>
void block_transpose(E *A, E *B, intT *OA, intT *OB, intT *L,
                     intT rStart, intT rCount, intT rLength,
                     intT cStart, intT cCount, intT cLength) {

  auto seq = [&] {
    for (intT i=rStart; i < rStart + rCount; i++)
      for (intT j=cStart; j < cStart + cCount; j++) {
        E* pa = A+OA[i*rLength + j];
        E* pb = B+OB[j*cLength + i];
        intT l = L[i*rLength + j];
        for (intT k=0; k < l; k++) *(pb++) = *(pa++);
      }
  };
  int total = cCount * rCount;
  spguard([&] { return total; }, [&] {
    if (cCount < 2 && rCount < 2) {
      seq();
    } else if (cCount > rCount) {
      intT l1 = cCount/2;
      intT l2 = cCount - cCount/2;
      fork2([&] { block_transpose(A, B, OA, OB, L,
                                  rStart,rCount,rLength,cStart,l1,cLength); },
        [&] { block_transpose(A, B, OA, OB, L,
                              rStart,rCount,rLength,cStart + l1,l2,cLength); });
    } else {
      intT l1 = rCount/2;
      intT l2 = rCount - rCount/2;
      fork2([&] { block_transpose(A, B, OA, OB, L,
                                  rStart,l1,rLength,cStart,cCount,cLength); },
        [&] { block_transpose(A, B, OA, OB, L,
                              rStart + l1,l2,rLength,cStart,cCount,cLength); });
    }
  }, seq);
}
  
template <class E, class intT>
void block_transpose(E *A, E *B, intT *OA, intT *OB, intT *L,
                     intT rCount, intT cCount) {
  block_transpose(A, B, OA, OB, L, 0,rCount,cCount,0,cCount,rCount);
}

  
} // end namespace

#endif
