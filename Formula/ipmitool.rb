class Ipmitool < Formula
  desc "Utility for IPMI control with kernel driver or LAN interface"
  homepage "https://codeberg.org/IPMITool/ipmitool"
  url "https://codeberg.org/IPMITool/ipmitool/archive/IPMITOOL_1_8_19.tar.gz"
  sha256 "ce13c710fea3c728ba03a2a65f2dd45b7b13382b6f57e25594739f2e4f20d010"
  license "BSD-3-Clause"
  revision 3
  head "https://codeberg.org/IPMITool/ipmitool.git", branch: "master"

  livecheck do
    url :head
    regex(/^IPMITOOL[._-]v?(\d+(?:[._]\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/ipmitool-1.8.19_3"
    sha256 sequoia: "a18a7481736ea480865d7a0f2fd4a1f4220223c5417723d09d3b1626b949cdd9"
  end

  depends_on "metril/intel-bottles/autoconf" => :build
  depends_on "metril/intel-bottles/automake" => :build
  depends_on "metril/intel-bottles/libtool" => :build
  depends_on "metril/intel-bottles/openssl@4"

  on_linux do
    depends_on "metril/intel-bottles/readline"
  end

  # Patch to fix lan print
  patch do
    url "https://github.com/ipmitool/ipmitool/commit/a61349b443c16821e4884cde5ad8c031d619631a.patch?full_index=1"
    sha256 "e026b8a5a5128714a0f36d05b4b26428dca3522dc889ebc21dc8888a2d3f1505"
    type :unofficial
    resolves "https://github.com/ipmitool/ipmitool/pull/389",
             "https://github.com/ipmitool/ipmitool/issues/388"
  end

  # Patch to fix enterprise-number URL due to IANA URL scheme change
  patch do
    url "https://codeberg.org/IPMITool/ipmitool/commit/1edb0e27e44196d1ebe449aba0b9be22d376bcb6.patch?full_index=1"
    sha256 "044363a930cf6a9753d8be2a036a0ee8c4243ce107eebc639dcb93e1e412e0ed"
    type :backport
    resolves "https://github.com/ipmitool/ipmitool/issues/377"
  end

  # Patch to fix build on ARM
  patch do
    url "https://codeberg.org/IPMITool/ipmitool/commit/206dba615d740a31e881861c86bcc8daafd9d5b1.patch?full_index=1"
    sha256 "86eba5d0000b2d1f3ce3ba4a23ccb5dd762d01fec0f9910a95e756c5399d7fb8"
    type :backport
    resolves "https://github.com/ipmitool/ipmitool/issues/332"
  end

  def install
    system "./bootstrap"
    system "./configure", *std_configure_args,
                          "--mandir=#{man}",
                          "--disable-intf-usb"
    system "make", "install"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ipmitool -V")
    if OS.mac?
      assert_match "No hostname specified!", shell_output("#{bin}/ipmitool 2>&1", 1)
    else # Linux
      assert_match "Could not open device", shell_output("#{bin}/ipmitool 2>&1", 1)
    end
  end
end
