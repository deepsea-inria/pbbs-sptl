
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
    kappa = 30.0;
    update_size_ratio = 1.1;
  } else if (hostname == "hiphi.aladdin.cs.cmu.edu") {
    kappa = 40.0;
    update_size_ratio = 1.2;
  } else if (hostname == "aware.aladdin.cs.cmu.edu") {
    kappa = 40.0;
    update_size_ratio = 1.2;
  } else if (hostname == "beast") {
    kappa = 30.0;
    update_size_ratio = 1.2;
  }
}
  
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
    load_presets_by_host();
    body(f);
  });
}
  
} // end namespace
} // end namespace

#endif
