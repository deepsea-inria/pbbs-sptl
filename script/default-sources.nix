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
    rev    = "22009e0665c15bbb21ed5b36c88ae2e0081554ca";
    sha256 = "0324fz1a13z1sj2z63lq2kicjm3408i88c0h8nc1sy0i3c6l21mh";
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
    rev    = "8e43897e08b9b4eff520f6f577af0ca410972b87";
    sha256 = "0iixavbll1gd1jh9k1llxh6nr8rl4251kb9m53flhc2pvkiyppy9";
  };

}
