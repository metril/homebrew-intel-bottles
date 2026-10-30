class ApacheSerf < Formula
  desc "High-performance asynchronous HTTP client library"
  homepage "https://serf.apache.org/"
  license "Apache-2.0"
  revision 1
  compatibility_version 1
  head "https://github.com/apache/serf.git", branch: "trunk"

  stable do
    url "https://www.apache.org/dyn/closer.lua?path=serf/serf-1.3.10.tar.bz2"
    mirror "https://archive.apache.org/dist/serf/serf-1.3.10.tar.bz2"
    sha256 "be81ef08baa2516ecda76a77adf7def7bc3227eeb578b9a33b45f7b41dc064e6"

    # Backport commit to use non-system zlib
    patch do
      url "https://github.com/apache/serf/commit/15ca053c4bfb00ad4d262686e1a30b5795b6ab81.patch?full_index=1"
      sha256 "d2ab43081a2fc60c6d00df1afc6946895921c91d09cac05a186f820282bea9c6"
      type :backport
    end

    # Apply minimal Fedora patch to fix build with OpenSSL until next release with:
    # https://github.com/apache/serf/commit/e8d61020b5f9afa21c06a1e2d72e7052d8e72225
    patch do
      url "https://src.fedoraproject.org/rpms/libserf/raw/b8f0ecc6dffd2e0cffc75f33644f0e16cc91862a/f/libserf-openssl4.patch"
      sha256 "09649037c9ff17e282ffae0fa0d65f0376b55d341359ba45a1df3f666615e193"
      type :unofficial
    end
  end

  bottle do
    root_url "https://github.com/metril/homebrew-intel-bottles/releases/download/apache-serf-1.3.10_1"
    sha256 cellar: :any, sequoia: "86ff2d2dd43669e087e2cfdeb4daaa39f9a40652d6d40f37c0100ed9dc778089"
  end

  depends_on "metril/intel-bottles/scons" => :build
  depends_on "metril/intel-bottles/pkgconf" => :test
  depends_on "metril/intel-bottles/apr"
  depends_on "metril/intel-bottles/apr-util"
  depends_on "metril/intel-bottles/openssl@4"

  uses_from_macos "krb5"

  on_linux do
    depends_on "zlib-ng-compat"
  end

  def openssl = "openssl@4"

  def install
    # scons ignores our compiler and flags unless explicitly passed
    args = %W[
      APR=#{formula_opt_prefix("apr")}
      APU=#{formula_opt_prefix("apr-util")}
      CC=#{ENV.cc}
      CFLAGS=#{ENV.cflags}
      GSSAPI=#{OS.mac? ? MacOS.sdk_for_formula(self).path/"usr" : formula_opt_prefix("krb5")}
      LINKFLAGS=#{ENV.ldflags}
      OPENSSL=#{formula_opt_prefix(openssl)}
      PREFIX=#{prefix}
    ]
    args << "ZLIB=#{formula_opt_prefix("zlib-ng-compat")}" if OS.linux?

    system "scons", *args
    system "scons", "install"
  end

  test do
    # Based on test_ssl_init from https://github.com/apache/serf/blob/trunk/test/test_ssl.c
    (testpath/"test.c").write <<~C
      #include <assert.h>
      #include <stdlib.h>
      #include <serf.h>

      int main(void) {
        apr_pool_t *pool;
        apr_status_t status;
        serf_bucket_t *decrypt_bkt;
        serf_bucket_t *encrypt_bkt;
        serf_bucket_t *in_stream;
        serf_bucket_t *out_stream;
        serf_bucket_alloc_t *alloc;
        serf_ssl_context_t *ssl_context;

        apr_initialize();
        atexit(apr_terminate);
        apr_pool_create(&pool, NULL);

        alloc = serf_bucket_allocator_create(pool, NULL, NULL);
        in_stream = SERF_BUCKET_SIMPLE_STRING("", alloc);
        out_stream = SERF_BUCKET_SIMPLE_STRING("", alloc);
        decrypt_bkt = serf_bucket_ssl_decrypt_create(in_stream, NULL, alloc);
        ssl_context = serf_bucket_ssl_decrypt_context_get(decrypt_bkt);
        encrypt_bkt = serf_bucket_ssl_encrypt_create(out_stream, ssl_context, alloc);
        status = serf_ssl_use_default_certificates(ssl_context);

        serf_bucket_destroy(decrypt_bkt);
        serf_bucket_destroy(encrypt_bkt);
        apr_pool_destroy(pool);
        assert(status == APR_SUCCESS);
        return 0;
      }
    C

    if OS.mac?
      ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("apr")/"pkgconfig"
      ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("apr-util")/"pkgconfig"
    end
    flags = shell_output("pkgconf --cflags --libs serf-1 apr-util-1 apr-1").chomp.split
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end
