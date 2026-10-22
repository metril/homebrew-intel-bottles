class M4 < Formula
  desc "Macro processing language"
  homepage "https://www.gnu.org/software/m4/"
  url "https://ftpmirror.gnu.org/m4/m4-1.4.21.tar.xz"
  mirror "https://ftp.gnu.org/gnu/m4/m4-1.4.21.tar.xz"
  mirror "http://ftp.gnu.org/gnu/m4/m4-1.4.21.tar.xz"
  sha256 "f25c6ab51548a73a75558742fb031e0625d6485fe5f9155949d6486a2408ab66"
  license "GPL-3.0-or-later"
  compatibility_version 1

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/m4-1.4.21"
    sha256 sequoia: "416b1f0d6a0650edaa17b00741a0a71cd4c1c653a50c61c4d282c3b1b436e170"
  end

  keg_only :provided_by_macos

  def install
    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}"
    system "make"
    system "make", "install"
  end

  test do
    assert_match "Homebrew",
      pipe_output(bin/"m4", "define(TEST, Homebrew)\nTEST\n")
  end
end
