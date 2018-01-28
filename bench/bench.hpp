
#include "readinputbinary.hpp"

#ifndef _PBBS_SPTL_BENCH_
#define _PBBS_SPTL_BENCH_

namespace sptl {
namespace bench {

using thunk_type = std::function<void()>;

using measured_type = std::function<void(thunk_type)>;
  
template <class Body>
void launch(int argc, char** argv, const Body& body) {
  auto f = [&] (thunk_type measured) {
    auto start = std::chrono::system_clock::now();
    measured();
    auto end = std::chrono::system_clock::now();
    std::chrono::duration<float> diff = end - start;
    printf ("exectime %.3lf\n", diff.count());
  };
  sptl::launch(argc, argv, [&] {
    body(f);
  });
}
  
} // end namespace
} // end namespace

#endif
