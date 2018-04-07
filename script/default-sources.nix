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
    rev    = "71c7275dc9cf5c6d5c179ef20215c0afde9416ed";
    sha256 = "0d9qmjkihglcq4v8jykw375c0i6jhymy7c60w06s9wh5mzk339sc";
  };

  chunkedseqSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "chunkedseq";
    rev    = "9a27b69a742fa6d207a4b4fcf5d5f7bee5b677b9";
    sha256 = "0crds1khg8l5hgprxnpr1zw4f1c0y8f2g704mnv9bngkmc1lizzh";
  };

  sptlSrc = pkgs.fetchFromGitHub {
    owner  = "deepsea-inria";
    repo   = "sptl";
    rev    = "818ada7fc8e1f5277ea1ad10c9f2c156d35eca42";
    sha256 = "1vdvpf8bmbr9sralymbprl55ccr3ikhj2virrh13d1irk6z09q78";
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
    rev    = "29b6c1338baf955a90673256f8e6c116292ec94e";
    sha256 = "09m5m15yxvqdf7kffvbka7mm6c1kh8jpzqn7ldil89ml034f6592";
  };

}