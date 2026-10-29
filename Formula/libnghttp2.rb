class Libnghttp2 < Formula
  desc "HTTP/2 C Library"
  homepage "https://nghttp2.org/"
  url "https://github.com/nghttp2/nghttp2/releases/download/v1.70.0/nghttp2-1.70.0.tar.gz"
  mirror "http://fresh-center.net/linux/www/nghttp2-1.70.0.tar.gz"
  mirror "http://fresh-center.net/linux/www/legacy/nghttp2-1.70.0.tar.gz"
  # this legacy mirror is for user to install from the source when https not working for them
  # see discussions in here, https://github.com/Homebrew/homebrew-core/pull/133078#discussion_r1221941917
  sha256 "aa317e2cf9dca6afa0aed68f8fad6ff303ec6982e25a78c75c0b65e2b9b3ded5"
  license "MIT"
  compatibility_version 1

  livecheck do
    formula "nghttp2"
  end

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/libnghttp2-1.70.0"
    sha256 cellar: :any, sequoia: "537a9a62dd6ea2bb696e75bfcad3a4604d805de55224e32463c5eb6e8e1fc4a5"
  end

  head do
    url "https://github.com/nghttp2/nghttp2.git", branch: "master"

    depends_on "metril/intel-bottles/autoconf" => :build
    depends_on "metril/intel-bottles/automake" => :build
    depends_on "metril/intel-bottles/libtool" => :build
  end

  depends_on "metril/intel-bottles/pkgconf" => :build

  # These used to live in `nghttp2`.
  link_overwrite "include/nghttp2"
  link_overwrite "lib/libnghttp2.a"
  link_overwrite "lib/libnghttp2.dylib"
  link_overwrite "lib/libnghttp2.14.dylib"
  link_overwrite "lib/libnghttp2.so"
  link_overwrite "lib/libnghttp2.so.14"
  link_overwrite "lib/pkgconfig/libnghttp2.pc"

  deny_network_access!

  def install
    system "autoreconf", "--force", "--install", "--verbose" if build.head?
    system "./configure", "--enable-lib-only", *std_configure_args
    system "make", "-C", "lib"
    system "make", "-C", "lib", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <nghttp2/nghttp2.h>
      #include <stdio.h>

      int main() {
        nghttp2_info *info = nghttp2_version(0);
        printf("%s", info->version_str);
        return 0;
      }
    C

    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lnghttp2", "-o", "test"
    assert_equal version.to_s, shell_output("./test")
  end
end
