class Chezmoi < Formula
  desc "Manage your dotfiles across multiple diverse machines, securely"
  homepage "https://chezmoi.io/"
  url "https://github.com/twpayne/chezmoi/releases/download/v2.74.2/chezmoi-2.74.2.tar.gz"
  sha256 "93aecfec5f1d55081ed4507f531db7de5a18738d6cb368b8cce827a37af18256"
  license "MIT"
  head "https://github.com/twpayne/chezmoi.git", branch: "master"

  # Upstream uses GitHub releases to indicate that a version is released,
  # so the `GithubLatest` strategy is necessary.
  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/chezmoi-2.74.2"
    sha256 cellar: :any_skip_relocation, sequoia: "d0b24deb43f215bc7ea24ce36450aaa09cec7c2ac194e075db49fb1be2ac6ffa"
  end

  depends_on "metril/intel-bottles/go" => :build

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args(ldflags: :goreleaser)

    bash_completion.install "completions/chezmoi-completion.bash" => "chezmoi"
    fish_completion.install "completions/chezmoi.fish"
    zsh_completion.install "completions/chezmoi.zsh" => "_chezmoi"
  end

  test do
    # test version to ensure that version number is embedded in binary
    output = shell_output("#{bin}/chezmoi --version")
    assert_match "version v#{version}", output
    assert_match "built by #{tap.user}", output

    system bin/"chezmoi", "init"
    assert_path_exists testpath/".local/share/chezmoi"
  end
end
