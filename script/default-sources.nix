let pkgs = import <nixpkgs> {}; in

{

  cmdlineSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "cmdline";
    rev    = "c5f96b4aecb2019b5a690176195d37f7df3ed34b";
    sha256 = "1rz9bfdd5242gy3vq4n9vj2rcr5pwp0j4cjycpn3pm7rnwrrcjnh";
  };

  cilkRtsSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "cilk-plus-rts-with-stats";
    rev    = "ae723bd498d9dd09dcfadefceca092d7e28d4352";
    sha256 = "0bgsi9aqhjb80ds2c9mb1m3jzs6y3hwd2683f8gg301giifv17dn";
  };

  pbenchSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "pbench";
    rev    = "6d862442713cae93153c439a3e5e5867e95af958";
    sha256 = "1qdsl2amaqkckp2r2s4j5az8b0bpkbrgf8nc0zp575l1yjdzi2hh";
  };

  chunkedseqSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "chunkedseq";
    rev    = "d2925cf385fb43aff7eeb9c08cce88d321e5e02e";
    sha256 = "09qyv48vb2ispl3zrxmvbziwf6vzjh3la7vl115qgmkq67cxv78b";
  };

  sptlSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "sptl";
    rev    = "c23515738313529846797778f1d81da8374168c6";
    sha256 = "1piv1a9aj1qdv08vnlvwdhkaqzin9my49i2pbkyi6x35bwsr50mh";
  };

  pbbsIncludeSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "pbbs-include";
    rev    = "ef5ce72c4b4c26af78f7d91ea9b51336cd83a2e9";
    sha256 = "1g64j8gv6s9ggzhr2ky0y55s404cm0yrmdbhi5q4gfqaczbymyr4";
  };

  pbbsSptlSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "pbbs-sptl";
    rev    = "772eb25050206fea91d6d42cf63c3b212a58d49b";
    sha256 = "0f5ifgnpnbvyv7chc06w46bvz5m005ji7d2yvyyq44gifrmmr53f";
  };

}
