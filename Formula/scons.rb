class Scons < Formula
  include Language::Python::Virtualenv

  desc "Substitute for classic 'make' tool with autoconf/automake functionality"
  homepage "https://www.scons.org/"
  url "https://files.pythonhosted.org/packages/42/b9/b7a5c88f348a0c34594d88100872c55fa1cae863ccb222c1c438341b5503/scons-4.11.1.tar.gz"
  sha256 "4210d1a80a62e986029208117991b6347ccaaaab37b67463a3ff31ee065dc487"
  license "MIT"
  compatibility_version 1

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/scons-4.11.1"
    sha256 cellar: :any_skip_relocation, sequoia: "70acb755949bd161e2219a97f286d189c09fa4c56e321561af8a0004bde896cd"
  end

  depends_on "metril/intel-bottles/python@3.15"

  def install
    virtualenv_install_with_resources
  end

  test do
    (testpath/"test.c").write <<~C
      #include <stdio.h>
      int main()
      {
        printf("Homebrew");
        return 0;
      }
    C
    (testpath/"SConstruct").write "Program('test.c')"
    system bin/"scons"
    assert_equal "Homebrew", shell_output("#{testpath}/test")
  end
end
