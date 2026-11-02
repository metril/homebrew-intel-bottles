class Zoxide < Formula
  desc "Shell extension to navigate your filesystem faster"
  homepage "https://github.com/ajeetdsouza/zoxide"
  url "https://github.com/ajeetdsouza/zoxide/archive/refs/tags/v0.10.0.tar.gz"
  sha256 "4fcd4272b013a10b637dbcc299c58a9924b94470a9042677ca1a204cc2e9150e"
  license "MIT"

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/zoxide-0.10.0"
    sha256 cellar: :any_skip_relocation, sequoia: "1dd75460c091331cfa6d73073422a00798ec342e87bf8ca81055ffc995d58ba5"
  end

  depends_on "metril/intel-bottles/rust" => :build

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args
    bash_completion.install "contrib/completions/zoxide.bash" => "zoxide"
    zsh_completion.install "contrib/completions/_zoxide"
    fish_completion.install "contrib/completions/zoxide.fish"
    share.install "man"
  end

  test do
    assert_empty shell_output("#{bin}/zoxide add /").strip
    assert_equal "/", shell_output("#{bin}/zoxide query").strip
  end
end
