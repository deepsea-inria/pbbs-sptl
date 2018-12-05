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
    rev    = "79a2467da1c8ff9292f7e6b1d7eb016a9f0f2d36";
    sha256 = "1f95jabm4pqbglkaqszbl5r72g14z9xh8cj3pyvw7154n9sqn007";
  };

  pbbsIncludeSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "pbbs-include";
    rev    = "ac791d6285f929af83f9491d0c4d7b5fe46200ee";
    sha256 = "1d521qy8hn1nqi34hk04xrsaky735yazswidn5m0zwvdax0v8br2";
  };

  pbbsSptlSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "pbbs-sptl";
    rev    = "13a1341cbfbfbe61ec995fb8b7d64fa5aed08556";
    sha256 = "09bw3p4d7j6chfrqpzcg3ygzkbjc0gpwy8pnaj18f7glmcl1sx5w";
  };

}
