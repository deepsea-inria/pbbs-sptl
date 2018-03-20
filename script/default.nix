{ pkgs   ? import <nixpkgs> {},
  stdenv ? pkgs.stdenv,
  fetchurl,
  pbench,
  sptl,
  pbbs-include,
  cmdline,
  chunkedseq,
  cilk-plus-rts-with-stats,
  gperftools,
  useHwloc ? false,
  hwloc,
  buildDocs ? false
}:

stdenv.mkDerivation rec {
  name = "pbbs-sptl-${version}";
  version = "v0.1-alpha";

  src = fetchurl {
    url = "https://github.com/deepsea-inria/pbbs-sptl/archive/${version}.tar.gz";
    sha256 = "0965aac2mycf8xp6hcypfdl2i8h8nnaivry7cqjwnk9jabdvxzzi";
  };

  buildInputs =
    let docs =
      if buildDocs then [
        pkgs.pandoc
        pkgs.texlive.combined.scheme-full
      ] else
        [];
    in
    [ pbench sptl pbbs-include cmdline chunkedseq ] ++ docs;
        
  buildPhase =
    let docs =
      if buildDocs then ''
        make -C doc pbbs-sptl.pdf pbbs-sptl.html
      ''
      else ''
        # nothing to build
      '';
    in
    let hwlocConfig =
      if useHwloc then ''
        USE_HWLOC=1
        USE_MANUAL_HWLOC_PATH=1
        MY_HWLOC_FLAGS=-I ${hwloc.dev}/include/
        MY_HWLOC_LIBS=-L ${hwloc.lib}/lib/ -lhwloc
      '' else "";
    in
    ''
    cat >> settings.sh <<__EOT__
    PBENCH_PATH=../pbench/
    CMDLINE_PATH=${cmdline}/include/
    CHUNKEDSEQ_PATH=${chunkedseq}/include/
    SPTL_PATH=${sptl}/include/
    PBBS_INCLUDE_PATH=${pbbs-include}/include/
    PBBS_SPTL_PATH=$out/include/
    USE_32_BIT_WORD_SIZE=1
    USE_CILK=1
    CUSTOM_MALLOC_PREFIX=-ltcmalloc -L${gperftools}/lib
    CILK_EXTRAS_PREFIX=-L ${cilk-plus-rts-with-stats}/lib -I  ${cilk-plus-rts-with-stats}/include -ldl -DCILK_RUNTIME_WITH_STATS
    __EOT__
    cat >> settings.sh <<__EOT__
    ${hwlocConfig}
    __EOT__
    ${docs}
    '';

  installPhase = ''
    mkdir -p $out/bench/
    cp settings.sh bench/Makefile bench/bench.ml bench/*.cpp bench/*.hpp $out/bench/
    mkdir -p $out/include/
    cp include/*.hpp $out/include/
    mkdir -p $out/doc
    cp doc/pbbs-sptl.* doc/Makefile $out/doc/
    '';

  meta = {
    description = "A port of the Problem Based Benchmark Suite that is based on the Series Parallel Template Library.";
    license = "MIT";
    homepage = http://deepsea.inria.fr/oracular/;
  };
}