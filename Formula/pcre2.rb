class Pcre2 < Formula
  desc "Perl compatible regular expressions library with a new API"
  homepage "https://www.pcre.org/"
  url "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.49/pcre2-10.49.tar.bz2"
  sha256 "53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384"
  license "BSD-3-Clause"
  compatibility_version 1

  livecheck do
    url :stable
    regex(/^pcre2[._-]v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/pcre2-10.49"
    sha256 cellar: :any, sequoia: "3621d20e25c607cc46aa8c9d36bf2e67e4b13e1b49a06d6b5d5b36293da66769"
  end

  head do
    url "https://github.com/PCRE2Project/pcre2.git", branch: "main"

    depends_on "metril/intel-bottles/autoconf" => :build
    depends_on "metril/intel-bottles/automake" => :build
    depends_on "metril/intel-bottles/libtool" => :build
  end

  uses_from_macos "bzip2"

  on_linux do
    depends_on "zlib-ng-compat"
  end

  deny_network_access!

  def install
    args = %w[
      --enable-pcre2-16
      --enable-pcre2-32
      --enable-pcre2grep-libz
      --enable-pcre2grep-libbz2
      --enable-jit
    ]

    args << "--enable-pcre2test-libedit" if OS.mac?

    system "./autogen.sh" if build.head?

    system "./configure", *args, *std_configure_args
    system "make"
    system "make", "install"
  end

  test do
    system bin/"pcre2grep", "regular expression", prefix/"README"
  end
end
