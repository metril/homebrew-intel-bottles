class Certifi < Formula
  desc "Mozilla CA bundle for Python"
  homepage "https://github.com/certifi/python-certifi"
  url "https://files.pythonhosted.org/packages/51/33/4cd27639502f010084bcef7a2036391dd637439901341ce1a530f36f6e51/certifi-2026.11.20.tar.gz"
  sha256 "af1cb240a8133f105aa52684a3a3258339d7f2fd0bd4e2812698ff5cf5588c4e"
  license "MPL-2.0"
  compatibility_version 1

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/certifi-2026.11.20"
    sha256 cellar: :any_skip_relocation, sequoia: "04427a3dd043c5378e1337ea55e1a32a566a2f7541e99b922ea437200a5f2663"
  end

  depends_on "metril/intel-bottles/python-setuptools" => :build
  depends_on "metril/intel-bottles/python@3.15" => [:build, :test]
  depends_on "metril/intel-bottles/ca-certificates" => :no_linkage

  deny_network_access!

  def install
    system python3, "-m", "pip", "install", *std_pip_args, "."

    # Use brewed ca-certificates PEM file instead of the bundled copy
    site_packages = prefix/Language::Python.site_packages(python3)
    rm site_packages/"certifi/cacert.pem"
    (site_packages/"certifi").install_symlink Formula["ca-certificates"].pkgetc/"cert.pem" => "cacert.pem"

    # Add symlinks to use on all externally-managed pythons
    extra_pythons = Keg.for(python3).to_formula.versioned_formulae.select { |f| f.version >= "3.12" }
    extra_site_packages_list = extra_pythons.map { |f| lib/"python#{f.version.major_minor}/site-packages" }
    python_version = Formula["python-freethreading"].version.major_minor
    extra_site_packages_list << (lib/"python#{python_version}t/site-packages")
    site_packages.find.select(&:file?).each do |path|
      extra_site_packages_list.each do |extra_site_packages|
        (extra_site_packages/path.relative_path_from(site_packages)).dirname.install_symlink path
      end
    end
  end

  test do
    output = shell_output("#{python3} -m certifi").chomp
    assert_equal Formula["ca-certificates"].pkgetc/"cert.pem", Pathname(output).realpath

    # Check that the wheel is safe to use on all pythons
    wheel = prefix/Language::Python.site_packages(python3)/"certifi-#{version}.dist-info/WHEEL"
    assert_match(/^Tag: py3-none-any$/, wheel.read)
  end
end
