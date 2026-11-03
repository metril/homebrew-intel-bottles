class AprUtil < Formula
  desc "Companion library to apr, the Apache Portable Runtime library"
  homepage "https://apr.apache.org/"
  url "https://www.apache.org/dyn/closer.lua?path=apr/apr-util-1.6.6.tar.bz2"
  mirror "https://archive.apache.org/dist/apr/apr-util-1.6.6.tar.bz2"
  sha256 "aa77dd25f036731b7246abbfbebe6cc813b42799b62c874bc82bd4e1f90f2918"
  license "Apache-2.0"
  compatibility_version 1

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/apr-util-1.6.6"
    sha256 sequoia: "1bf886633a8738245ace99a96f4a96cbfe065a09bfcddc6a8fa79979c9847924"
  end

  keg_only :shadowed_by_macos, "Apple's CLT provides apr (but not apr-util)"

  depends_on "metril/intel-bottles/apr"
  depends_on "metril/intel-bottles/openssl@4"

  uses_from_macos "expat"
  uses_from_macos "libxcrypt"
  uses_from_macos "sqlite"

  on_linux do
    depends_on "unixodbc"
  end

  deny_network_access!

  def install
    system "./configure", "--with-apr=#{formula_opt_prefix("apr")}",
                          "--with-crypto",
                          "--with-openssl=#{formula_opt_prefix("openssl@4")}",
                          "--without-pgsql",
                          *std_configure_args
    system "make"
    system "make", "install"

    # Install symlinks so that linkage doesn't break for reverse dependencies.
    # This should be removed on the next ABI breaking update.
    (libexec/"lib").install_symlink Dir["#{lib}/#{shared_library("*")}"]

    rm Dir[lib/"**/*.{la,exp}"]

    # No need for this to point to the versioned path.
    inreplace bin/"apu-#{version.major}-config", prefix, opt_prefix
  end

  test do
    assert_match opt_prefix.to_s, shell_output("#{bin}/apu-#{version.major}-config --prefix")
  end
end
