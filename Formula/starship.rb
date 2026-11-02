class Starship < Formula
  desc "Cross-shell prompt for astronauts"
  homepage "https://starship.rs/"
  url "https://github.com/starship/starship/archive/refs/tags/v1.27.0.tar.gz"
  sha256 "f1887ffa88a7ba437d2932501794047e28d03387996f7d1c364631c053cffc44"
  license "ISC"
  head "https://github.com/starship/starship.git", branch: "main"

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/starship-1.27.0"
    sha256 cellar: :any_skip_relocation, sequoia: "c31ede41807421730524b2e2e1e15384ad88bd79a6c09030ccb703d92c53dde8"
  end

  depends_on "metril/intel-bottles/cmake" => :build
  depends_on "metril/intel-bottles/pkgconf" => :build
  depends_on "metril/intel-bottles/rust" => :build

  on_linux do
    depends_on "dbus"
    depends_on "zlib-ng-compat"
  end

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args

    generate_completions_from_executable(bin/"starship", "completions")
  end

  test do
    ENV["STARSHIP_CONFIG"] = ""
    assert_equal "[1;32m❯[0m ", shell_output("#{bin}/starship module character")
  end
end
