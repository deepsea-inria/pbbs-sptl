{ pkgs   ? import <nixpkgs> {},
  stdenv ? pkgs.stdenv,
  pbbsSptlSrc ? ../.,
  pbench ? ../../pbench,
  sptl ? ../../sptl,
  pbbs-include ? ../../pbbs-include,
  cmdline ? ../../cmdline,
  chunkedseq ? ../../chunkedseq,
  cilk-plus-rts-with-stats ? ../../cilk-plus-rts-with-stats,
  gperftools ? pkgs.gperftools,
  useHwloc ? false,
  hwloc ? pkgs.hwloc,
  buildDocs ? false
}:

# Later: make gperftools and hwloc options a la mkOption

stdenv.mkDerivation rec {
  name = "pbbs-sptl";

  src = pbbsSptlSrc;

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
    ''
    ${docs}
    '';

  installPhase =
    let hwlocConfig =
      if useHwloc then ''
        USE_HWLOC=1
        USE_MANUAL_HWLOC_PATH=1
        MY_HWLOC_FLAGS=-I ${hwloc.dev}/include/
        MY_HWLOC_LIBS=-L ${hwloc.lib}/lib/ -lhwloc
      '' else "";
    in
    let settingsScript = pkgs.writeText "settings.sh" ''
      PBENCH_PATH=../pbench/
      CMDLINE_PATH=${cmdline}/include/
      CHUNKEDSEQ_PATH=${chunkedseq}/include/
      SPTL_PATH=${sptl}/include/
      PBBS_INCLUDE_PATH=${pbbs-include}/include/
      USE_32_BIT_WORD_SIZE=1
      USE_CILK=1
      CUSTOM_MALLOC_PREFIX=-ltcmalloc -L${gperftools}/lib
      CILK_EXTRAS_PREFIX=-L ${cilk-plus-rts-with-stats}/lib -I  ${cilk-plus-rts-with-stats}/include -ldl -DCILK_RUNTIME_WITH_STATS
      ${hwlocConfig}    
    '';
    in
    ''
    mkdir -p $out/bench/
    cat >> $out/bench/settings.sh <<__EOT__
    PBBS_SPTL_PATH=$out/include/
    __EOT__
    cat ${settingsScript} >> $out/bench/settings.sh
    cp bench/Makefile bench/bench.ml bench/*.cpp bench/*.hpp $out/bench/
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