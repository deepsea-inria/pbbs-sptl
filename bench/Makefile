
PACKAGE_PATH=../../
CMDLINE_HOME=$(PACKAGE_PATH)/cmdline/include
CHUNKEDSEQ_HOME=$(PACKAGE_PATH)/chunkedseq/include
SPTL_HOME=$(PACKAGE_PATH)/sptl/include
PBBS_SPTL_HOME=$(PACKAGE_PATH)/pbbs-sptl/include
PBBS_HOME=$(PACKAGE_PATH)/pbbs-include/

INCLUDE_FILES=$(wildcard $(CHUNKEDSEQ_HOME)/*.hpp) $(wildcard $(CMDLINE_HOME)/*.hpp) $(wildcard $(SPTL_HOME)/*.hpp) $(wildcard $(PBBS_SPTL_HOME)/*.hpp) $(wildcard $(PBBS_HOME)/*.hpp)

INCLUDE_DIRECTIVES=-I $(CHUNKEDSEQ_HOME) -I $(CMDLINE_HOME) -I $(SPTL_HOME) -I $(PBBS_SPTL_HOME) -I $(PBBS_HOME)

COMMON_PREFIX=-std=c++11 -DTARGET_LINUX -Wno-subobject-linkage -Wno-overflow
DEBUG_PREFIX=$(COMMON_PREFIX) -g -O0
OPT_PREFIX=$(COMMON_PREFIX) -O2 -march=native -DNDEBUG -m64 -lm

%.dbg: %.cpp $(INCLUDE_FILES)
	g++ $(DEBUG_PREFIX) $(INCLUDE_DIRECTIVES) -o $@ $<

%.opt: %.cpp $(INCLUDE_FILES)
	g++ $(OPT_PREFIX) $(INCLUDE_DIRECTIVES) -o $@ $<

clean:
	rm -f *.dbg *.opt
