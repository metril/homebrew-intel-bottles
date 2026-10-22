class Smartmontools < Formula
  desc "SMART hard drive monitoring"
  homepage "https://www.smartmontools.org/"
  url "https://downloads.sourceforge.net/project/smartmontools/smartmontools/7.5/smartmontools-7.5.tar.gz"
  sha256 "690b83ca331378da9ea0d9d61008c4b22dde391387b9bbad7f29387f2595f76e"
  license "GPL-2.0-or-later"
  compatibility_version 1

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/smartmontools-7.5"
    sha256 cellar: :any_skip_relocation, sequoia: "b8fcf16bcccea2c86818a22192a03a03edaf451587e4c9883278df4d89aad10f"
  end

  deny_network_access!

  def install
    (var/"run").mkpath
    (var/"lib/smartmontools").mkpath

    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--sbindir=#{bin}",
                          "--sysconfdir=#{etc}",
                          "--localstatedir=#{var}",
                          "--with-savestates",
                          "--with-attributelog",
                          "--with-nvme-devicescan"
    system "make", "install"
  end

  test do
    system bin/"smartctl", "--version"
    system bin/"smartd", "--version"
  end
end
