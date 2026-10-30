class Oniguruma < Formula
  desc "Regular expressions library"
  homepage "https://github.com/kkos/oniguruma/"
  url "https://github.com/kkos/oniguruma/releases/download/v6.9.10/onig-6.9.10.tar.gz"
  sha256 "2a5cfc5ae259e4e97f86b68dfffc152cdaffe94e2060b770cb827238d769fc05"
  license "BSD-2-Clause"
  compatibility_version 1
  head "https://github.com/kkos/oniguruma.git", branch: "master"

  livecheck do
    skip "No longer developed or maintained"
  end

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/oniguruma-6.9.10"
    sha256 cellar: :any, sequoia: "11cadbe69abcdde42e4e5dbf830e24d24c0c276c06e3dd38e7b64ae81d4de444"
  end

  depends_on "metril/intel-bottles/autoconf" => :build
  depends_on "metril/intel-bottles/automake" => :build
  depends_on "metril/intel-bottles/libtool" => :build

  def install
    system "autoreconf", "--force", "--install", "--verbose"
    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}"
    system "make"
    system "make", "install"
  end

  test do
    assert_match(/#{prefix}/, shell_output("#{bin}/onig-config --prefix"))
  end
end
