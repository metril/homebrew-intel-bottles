class Iperf3 < Formula
  desc "Update of iperf: measures TCP, UDP, and SCTP bandwidth"
  homepage "https://github.com/esnet/iperf"
  url "https://downloads.es.net/pub/iperf/iperf-3.22.1.tar.gz"
  sha256 "de018b5252e2a7068c89fac8b35a295d83334f2b7814aa9532a2a8107b04a4a9"
  license "BSD-3-Clause"

  livecheck do
    url "https://downloads.es.net/pub/iperf/"
    regex(/href=.*?iperf[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/iperf3-3.22.1"
    sha256 cellar: :any, sequoia: "ead8bb377f83d7f006185c06869692c893f004f319c30d760bb31c7e13777b11"
  end

  head do
    url "https://github.com/esnet/iperf.git", branch: "master"

    depends_on "metril/intel-bottles/autoconf" => :build
    depends_on "metril/intel-bottles/automake" => :build
    depends_on "metril/intel-bottles/libtool" => :build
  end

  depends_on "metril/intel-bottles/openssl@4"

  allow_network_access! :test

  def install
    system "./bootstrap.sh" if build.head?
    openssl_prefix = dep("openssl").opt_prefix
    system "./configure", "--disable-silent-rules",
                          "--disable-profiling",
                          "--with-openssl=#{openssl_prefix}",
                          *std_configure_args
    system "make", "clean" # there are pre-compiled files in the tarball
    system "make", "install"
  end

  test do
    port = free_port
    with_test_process(bin/"iperf3", "--server", "--port", port.to_s, signal: "INT") do
      sleep 1
      assert_match "Bitrate", shell_output("#{bin}/iperf3 --client 127.0.0.1 --port #{port} --time 1")
    end
  end
end
