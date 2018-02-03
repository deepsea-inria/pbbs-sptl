
PBENCH_PATH=../../pbench

include $(PBENCH_PATH)/Makefile_common

PACKAGE_PATH=../../
CMDLINE_HOME=$(PACKAGE_PATH)/cmdline/include
CHUNKEDSEQ_HOME=$(PACKAGE_PATH)/chunkedseq/include
SPTL_HOME=$(PACKAGE_PATH)/sptl/include
PBBS_SPTL_HOME=$(PACKAGE_PATH)/pbbs-sptl/include
PBBS_HOME=$(PACKAGE_PATH)/pbbs-include/

INCLUDE_FILES=$(wildcard $(CHUNKEDSEQ_HOME)/*.hpp) $(wildcard $(CMDLINE_HOME)/*.hpp) $(wildcard $(SPTL_HOME)/*.hpp) $(wildcard $(PBBS_SPTL_HOME)/*.hpp) $(wildcard $(PBBS_HOME)/*.hpp)

INCLUDE_DIRECTIVES=-I $(CHUNKEDSEQ_HOME) -I $(CMDLINE_HOME) -I $(SPTL_HOME) -I $(PBBS_SPTL_HOME) -I $(PBBS_HOME)

####################################################################
# Makefile options

# Create a file called "settings.sh" in this folder if you want to
# configure particular options. See section below for options.

-include settings.sh

HWLOC_FLAGS=`pkg-config --cflags hwloc`
HWLOC_LIBS=`pkg-config --libs hwloc`
HWLOC_PREFIX_ALL=-DSPTL_HAVE_HWLOC $(HWLOC_FLAGS) $(HWLOC_LIBS)

HWLOC_PREFIX=
ifeq ($(strip $(USE_HWLOC)),1)
   HWLOC_PREFIX=$(HWLOC_PREFIX_ALL)
endif

CILK_PREFIX=
ifeq ($(strip $(USE_CILK)),1)
	CILK_PREFIX=-fcilkplus -lcilkrts -DSPTL_USE_CILK_PLUS_RUNTIME -DUSE_CILK_PLUS_RUNTIME
endif

WARNINGS_PREFIX=-Wno-subobject-linkage -Wno-overflow
COMMON_PREFIX=-std=c++1y -DSPTL_TARGET_LINUX -DSPTL_SIZE_BITS32 $(WARNINGS_PREFIX) $(HWLOC_PREFIX)
RUNTIME_PREFIX=$(CILK_PREFIX)
DEBUG_PREFIX=$(COMMON_PREFIX) $(RUNTIME_PREFIX) -g -O0
O2_PREFIX=-O2 -march=native -DNDEBUG -m64 -lm
SPTL_PREFIX=$(COMMON_PREFIX) $(RUNTIME_PREFIX) $(O2_PREFIX)
SPTL_ELISION_PREFIX=$(COMMON_PREFIX) $(O2_PREFIX)
LOG_PREFIX=$(SPTL_PREFIX) $(RUNTIME_PREFIX) -DSPTL_ENABLE_LOGGING

%.dbg: %.cpp $(INCLUDE_FILES)
	g++ $(DEBUG_PREFIX) $(INCLUDE_DIRECTIVES) -o $@ $<

%.sptl: %.cpp $(INCLUDE_FILES)
	g++ $(SPTL_PREFIX) $(INCLUDE_DIRECTIVES) -o $@ $<

%.sptl_elision: %.cpp $(INCLUDE_FILES)
	g++ $(SPTL_ELISION_PREFIX) $(INCLUDE_DIRECTIVES) -o $@ $<

%.log: %.cpp $(INCLUDE_FILES)
	g++ $(LOG_PREFIX) $(INCLUDE_DIRECTIVES) -o $@ $<

clean: pbench_clean
	rm -f *.dbg *.sptl *.sptl_elision *.log
