{ pkgs   ? import (fetchTarball https://github.com/NixOS/nixpkgs/archive/18.09.tar.gz) {},
  stdenv ? pkgs.stdenv,
  sources ? import ./default-sources.nix,
  gperftools ? pkgs.gperftools,
  hwloc ? pkgs.hwloc,
  libunwind ? pkgs.libunwind,
  useLibunwind ? false,
  gcc ? pkgs.gcc,
  ocaml ? pkgs.ocaml_4_02,
  pathToResults ? "",
  pathToData ? "",
  buildDocs ? false
}:

let

  callPackage = pkgs.lib.callPackageWith (pkgs // sources // self);

  self = {

    ocaml = ocaml;

    hwloc = hwloc;

    libunwind = libunwind;
    useLibunwind = useLibunwind;

    gperftools = gperftools;

    gcc = gcc;

    buildDocs = buildDocs;

    pbench = callPackage "${sources.pbenchSrc}/script/default.nix" { };
    cmdline = callPackage "${sources.cmdlineSrc}/script/default.nix" { };
    cilk-plus-rts-with-stats = callPackage "${sources.cilkRtsSrc}/script/default.nix" { };
    chunkedseq = callPackage "${sources.chunkedseqSrc}/script/default.nix" { };
    sptl = callPackage "${sources.sptlSrc}/script/default.nix" { };
    pbbs-include = callPackage "${sources.pbbsIncludeSrc}/default.nix" { };
    pbbsSptlSrc = sources.pbbsSptlSrc;
    
  };

in

with self;

stdenv.mkDerivation rec {
  name = "pbbs-sptl";

  src = pbbsSptlSrc;

  buildInputs =
    let docs =
      if buildDocs then
        let pandocCiteproc = pkgs.haskellPackages.ghcWithPackages (pkgs: with pkgs; [pandoc-citeproc]);
        in
        [ pkgs.pandoc pandocCiteproc ]
      else [];
    in
    let lu =
      if useLibunwind then [ libunwind ] else [];
    in
    [ pbench sptl pbbs-include cmdline chunkedseq
      pkgs.makeWrapper pkgs.R pkgs.texlive.combined.scheme-small
      gcc ocaml
    ] ++ docs ++ lu;

  configurePhase =
    let hwlocConfig =
      ''
        USE_HWLOC=1
        USE_MANUAL_HWLOC_PATH=1
        MY_HWLOC_FLAGS=-I ${hwloc.dev}/include/
        MY_HWLOC_LIBS=-L ${hwloc.lib}/lib/ -lhwloc
      '';
    in
    let settingsScript = pkgs.writeText "settings.sh" ''
      PBENCH_PATH=../pbench/
      CMDLINE_PATH=${cmdline}/include/
      CHUNKEDSEQ_PATH=${chunkedseq}/include/
      SPTL_PATH=${sptl}/include/
      PBBS_INCLUDE_PATH=${pbbs-include}
      USE_32_BIT_WORD_SIZE=1
      USE_CILK=1
      CUSTOM_MALLOC_PREFIX=-ltcmalloc -L${gperftools}/lib
      CILK_EXTRAS_PREFIX=-L ${cilk-plus-rts-with-stats}/lib -I  ${cilk-plus-rts-with-stats}/include -DCILK_RUNTIME_WITH_STATS
      ${hwlocConfig}    
    '';
    in
    ''
    cp -r --no-preserve=mode ${pbench} pbench
    cp ${settingsScript} bench/settings.sh
    '';

  buildPhase =
    let docs =
      if buildDocs then ''
        make -C doc pbbs-sptl.pdf pbbs-sptl.html
      '' else "";
    in
    let getNbCoresScript = pkgs.writeScript "get-nb-cores.sh" ''
      #!/usr/bin/env bash
      ${sptl}/bin/get-nb-cores.sh
    '';
    in
    let autotuneScript = pkgs.writeScript "autotune" ''
      #!/usr/bin/env bash
      ${sptl}/bin/autotune
    '';
    in
    ''
    ${docs}
    cp ${getNbCoresScript} bench/
    cp ${autotuneScript} bench/autotune
    make -C bench bench.pbench
    '';  

  installPhase =
    let lu =
        if useLibunwind then
           ''--prefix LD_LIBRARY_PATH ":" ${libunwind}/lib''
        else "";
    in
    let hw =
        ''--prefix LD_LIBRARY_PATH ":" ${hwloc.lib}/lib'';
    in
    let nmf = "-skip make";
    in
    let rf =
      if pathToResults != "" then
        "-path_to_results ${pathToResults}"
      else "";
    in
    let df =
      if pathToData != "" then
        "-path_to_data ${pathToData}"
      else "";
    in
    let scp = "-sptl_config_path $out/sptl/autotune-results/";
    in
    let flags = "${nmf} ${rf} ${df} ${scp}";
    in
    let ipgetScript = pkgs.writeScript "ipget.sh" ''
      #!/usr/bin/env bash
      ${pkgs.ipget}/bin/ipget -o $2 $3 2>/dev/null 
    '';
    in
    ''
    mkdir -p $out/bench/
    cp bench/bench.pbench bench/timeout.out $out/bench/
    cp ${ipgetScript} $out/bench/ipget
    wrapProgram $out/bench/bench.pbench --prefix PATH ":" ${pkgs.R}/bin \
       --prefix PATH ":" ${pkgs.texlive.combined.scheme-small}/bin \
       --prefix PATH ":" ${gcc}/bin \
       --prefix PATH ":" $out/bench \
       --prefix LD_LIBRARY_PATH ":" ${gcc}/lib \
       --prefix LD_LIBRARY_PATH ":" ${gcc}/lib64 \
       --prefix LD_LIBRARY_PATH ":" ${gperftools}/lib \
       --prefix LD_LIBRARY_PATH ":" ${cilk-plus-rts-with-stats}/lib \
       --set TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD 100000000000 \
       ${lu} \
       ${hw} \
       --add-flags "${flags}"
    pushd bench
    $out/bench/bench.pbench compare -only make
    $out/bench/bench.pbench bfs -only make
    popd
    cp bench/autotune $out/bench/autotune
    cp bench/*.sptl bench/*.sptl_elision bench/*.sptl_nograin $out/bench/
    mkdir -p $out/doc
    cp doc/pbbs-sptl.* doc/Makefile $out/doc/
    ln -s ${sptl} $out/sptl
    '';

  meta = {
    description = "A port of the Problem Based Benchmark Suite that is based on the Series Parallel Template Library.";
    license = "MIT";
    homepage = http://deepsea.inria.fr/oracular/;
  };
}
