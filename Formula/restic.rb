class Restic < Formula
  desc "Fast, efficient and secure backup program"
  homepage "https://restic.net/"
  url "https://github.com/restic/restic/archive/refs/tags/v0.19.1.tar.gz"
  sha256 "bb9b1a19040744d26d8a79be029d4e6b189c45ccc9d8831d7fe367d3c33df725"
  license "BSD-2-Clause"
  compatibility_version 1
  head "https://github.com/restic/restic.git", branch: "master"

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/restic-0.19.1"
    sha256 cellar: :any_skip_relocation, sequoia: "8d4b1c0a09221c260f1f93e94ea395b74fb26bf6ee5e057fb4fd7c2076dd38dc"
  end

  depends_on "metril/intel-bottles/go" => :build

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "run", "build.go"

    mkdir "completions"
    system "./restic", "generate", "--bash-completion", "completions/restic"
    system "./restic", "generate", "--zsh-completion", "completions/_restic"
    system "./restic", "generate", "--fish-completion", "completions/restic.fish"

    mkdir "man"
    system "./restic", "generate", "--man", "man"

    bin.install "restic"
    bash_completion.install "completions/restic"
    zsh_completion.install "completions/_restic"
    fish_completion.install "completions/restic.fish"
    man1.install Dir["man/*.1"]
  end

  test do
    mkdir testpath/"restic_repo"
    ENV["RESTIC_REPOSITORY"] = testpath/"restic_repo"
    ENV["RESTIC_PASSWORD"] = "foo"

    (testpath/"testfile").write("This is a testfile")

    system bin/"restic", "init"
    system bin/"restic", "backup", "testfile"

    system bin/"restic", "restore", "latest", "-t", testpath/"restore"
    assert compare_file "testfile", testpath/"restore/testfile"
  end
end
