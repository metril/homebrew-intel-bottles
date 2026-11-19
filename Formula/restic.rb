class Restic < Formula
  desc "Fast, efficient and secure backup program"
  homepage "https://restic.net/"
  url "https://github.com/restic/restic/archive/refs/tags/v0.20.0.tar.gz"
  sha256 "7def5bbe05e62640f7b030b865b6f304701fd876f7836f5a6a603b56e1f4e30a"
  license "BSD-2-Clause"
  compatibility_version 1
  head "https://github.com/restic/restic.git", branch: "master"

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/restic-0.20.0"
    sha256 cellar: :any_skip_relocation, sequoia: "b0d42296d048fd14ff39906e784cd9504a2a9884edc5676b38faff76b3b9ab23"
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
