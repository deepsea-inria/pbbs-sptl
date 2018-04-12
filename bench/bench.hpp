
#include <unistd.h>
#include <limits.h>

#include "readinputbinary.hpp"

#ifndef _PBBS_SPTL_BENCH_
#define _PBBS_SPTL_BENCH_

namespace sptl {
namespace bench {

using thunk_type = std::function<void()>;

using measured_type = std::function<void(thunk_type)>;

void load_presets_by_host() {
  if (deepsea::cmdline::parse_or_default_bool("sptl_custom_kappa", false)) {
    return;
  }
  char _hostname[HOST_NAME_MAX];
  gethostname(_hostname, HOST_NAME_MAX);
  std::string hostname = std::string(_hostname);
  if (hostname == "teraram") {
    kappa = 25.0;
    update_size_ratio = 1.5;
  } else if (hostname == "cadmium") {
    kappa = 25.0;
    update_size_ratio = 1.5;
  } else if (hostname == "hiphi.aladdin.cs.cmu.edu") {
    kappa = 40.0;
    update_size_ratio = 1.2;
  } else if (hostname == "aware.aladdin.cs.cmu.edu") {
    kappa = 4.2;
    update_size_ratio = 1.4;
  } else if (hostname == "beast") {
    kappa = 30.0;
    update_size_ratio = 1.2;
  } else if (hostname == "keith_analog") {
    kappa = 10.2;
    update_size_ratio = 3.0;
  }
}

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
    load_presets_by_host();
    body(f);
  });
  printf("used_kappa %f\n", kappa);
  printf("used_alpha %f\n", update_size_ratio);
}
  
} // end namespace
} // end namespace

#endif
