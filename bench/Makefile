
PACKAGE_PATH=../../
CMDLINE_HOME=$(PACKAGE_PATH)/cmdline/include
CHUNKEDSEQ_HOME=$(PACKAGE_PATH)/chunkedseq/include
SPTL_HOME=$(PACKAGE_PATH)/sptl/include
PBBS_SPTL_HOME=$(PACKAGE_PATH)/pbbs-sptl/include
PBBS_HOME=$(PACKAGE_PATH)/pbbs-include/

INCLUDE_FILES=$(wildcard $(CHUNKEDSEQ_HOME)/*.hpp) $(wildcard $(CMDLINE_HOME)/*.hpp) $(wildcard $(SPTL_HOME)/*.hpp) $(wildcard $(PBBS_SPTL_HOME)/*.hpp) $(wildcard $(PBBS_HOME)/*.hpp)

INCLUDE_DIRECTIVES=-I $(CHUNKEDSEQ_HOME) -I $(CMDLINE_HOME) -I $(SPTL_HOME) -I $(PBBS_SPTL_HOME) -I $(PBBS_HOME)

CILK_PREFIX=-fcilkplus -lcilkrts -DSPTL_USE_CILK_PLUS_RUNTIME -DUSE_CILK_PLUS_RUNTIME
WARNINGS_PREFIX=-Wno-subobject-linkage -Wno-overflow
COMMON_PREFIX=-std=c++1y -DTARGET_LINUX $(WARNINGS_PREFIX) $(CILK_PREFIX)
DEBUG_PREFIX=$(COMMON_PREFIX) -g -O0
OPT_PREFIX=$(COMMON_PREFIX) -O2 -march=native -DNDEBUG -m64 -lm
LOG_PREFIX=$(OPT_PREFIX) -DSPTL_ENABLE_LOGGING

%.dbg: %.cpp $(INCLUDE_FILES)
	g++ $(DEBUG_PREFIX) $(INCLUDE_DIRECTIVES) -o $@ $<

%.opt: %.cpp $(INCLUDE_FILES)
	g++ $(OPT_PREFIX) $(INCLUDE_DIRECTIVES) -o $@ $<

%.log: %.cpp $(INCLUDE_FILES)
	g++ $(LOG_PREFIX) $(INCLUDE_DIRECTIVES) -o $@ $<

clean:
	rm -f *.dbg *.opt
