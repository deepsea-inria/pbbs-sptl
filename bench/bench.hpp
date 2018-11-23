
#include <unistd.h>
#include <limits.h>

#include "readinputbinary.hpp"

#ifndef _PBBS_SPTL_BENCH_
#define _PBBS_SPTL_BENCH_

namespace sptl {
namespace bench {

using thunk_type = std::function<void()>;

using measured_type = std::function<void(thunk_type)>;

/* To use the Cilk Plus runtime which supports custom statistics, set
 * the environment variable as such:
 *
 *   export LD_LIBRARY_PATH=../../cilk-plus-rts/lib:$LD_LIBRARY_PATH
 */
  
template <class Body>
void launch(int argc, char** argv, const Body& body) {
  deepsea::cmdline::set(argc, argv);
  unsigned nb_proc = deepsea::cmdline::parse_or_default_int("proc", 1);
  auto f = [&] (thunk_type measured) {
#if defined(CILK_RUNTIME_WITH_STATS)
    __cilkg_take_snapshot_for_stats();
#elif defined(SPTL_USE_FIBRIL)
    fibril_rt_log_stats_reset();
#endif
    auto start = std::chrono::system_clock::now();
    measured();
    auto end = std::chrono::system_clock::now();
    std::chrono::duration<float> diff = end - start;
#ifdef CILK_RUNTIME_WITH_STATS
    __cilkg_dump_encore_stats_to_stderr();
#endif
    printf ("exectime %.3lf\n", diff.count());
  };
  sptl::launch(argc, argv, nb_proc, [&] {
    body(f);
  });
  printf("used_kappa %f\n", kappa);
  printf("used_alpha %f\n", update_size_ratio);
}
  
} // end namespace
} // end namespace

#endif
