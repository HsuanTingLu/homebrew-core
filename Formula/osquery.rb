class Osquery < Formula
  desc "SQL powered operating system instrumentation and analytics"
  homepage "https://osquery.io"
  # pull from git tag to get submodules
  url "https://github.com/facebook/osquery.git",
    :tag => "1.7.3",
    :revision => "6901aa644a9bcc0667207008db71471abf756b82"

  bottle do
    cellar :any
    revision 2
    sha256 "478bdc556f34b100381665b9553af3f5527a0ccb7d51c91cd989d3bd63a525e2" => :el_capitan
    sha256 "382b88d2596337f17abdcb6d66b083977673f18c7f41e394bb68ce785acb7a15" => :yosemite
    sha256 "98243f2e24824430971e51b79edf5034e30bd65db94db27e8f40af0a493cbc7b" => :mavericks
  end

  # osquery only supports OS X 10.9 and above. Do not remove this.
  depends_on :macos => :mavericks

  depends_on "cmake" => :build
  depends_on "doxygen" => :build
  depends_on "boost"
  depends_on "rocksdb"
  depends_on "thrift"
  depends_on "yara"
  depends_on "libressl"
  depends_on "gflags"
  depends_on "glog"
  depends_on "libmagic"
  depends_on "cpp-netlib"
  depends_on "sleuthkit"

  resource "markupsafe" do
    url "https://pypi.python.org/packages/source/M/MarkupSafe/MarkupSafe-0.23.tar.gz"
    sha256 "a4ec1aff59b95a14b45eb2e23761a0179e98319da5a7eb76b56ea8cdc7b871c3"
  end

  resource "jinja2" do
    url "https://pypi.python.org/packages/source/J/Jinja2/Jinja2-2.7.3.tar.gz"
    sha256 "2e24ac5d004db5714976a04ac0e80c6df6e47e98c354cb2c0d82f8879d4f8fdb"
  end

  resource "psutil" do
    url "https://pypi.python.org/packages/source/p/psutil/psutil-2.2.1.tar.gz"
    sha256 "a0e9b96f1946975064724e242ac159f3260db24ffa591c3da0a355361a3a337f"
  end

  def install
    # Link dynamically against brew-installed libraries.
    ENV["BUILD_LINK_SHARED"] = "1"

    # Use LibreSSL instead of the system provided OpenSSL.
    ENV["BUILD_USE_LIBRESSL"] = "1"

    # Skip test and benchmarking.
    ENV["SKIP_TESTS"] = "1"

    ENV.prepend_create_path "PYTHONPATH", buildpath/"third-party/python/lib/python2.7/site-packages"
    ENV["THRIFT_HOME"] = Formula["thrift"].opt_prefix

    resources.each do |r|
      r.stage do
        system "python", "setup.py", "install",
                                 "--prefix=#{buildpath}/third-party/python/",
                                 "--single-version-externally-managed",
                                 "--record=installed.txt"
      end
    end

    system "cmake", ".", *std_cmake_args
    system "make"
    system "make", "install"
  end

  plist_options :startup => true, :manual => "osqueryd"

  test do
    (testpath/"test.cpp").write <<-EOS.undent
      #include <osquery/sdk.h>

      using namespace osquery;

      class ExampleTablePlugin : public TablePlugin {
       private:
        TableColumns columns() const {
          return {{"example_text", TEXT_TYPE}, {"example_integer", INTEGER_TYPE}};
        }

        QueryData generate(QueryContext& request) {
          QueryData results;
          Row r;

          r["example_text"] = "example";
          r["example_integer"] = INTEGER(1);
          results.push_back(r);
          return results;
        }
      };

      REGISTER_EXTERNAL(ExampleTablePlugin, "table", "example");

      int main(int argc, char* argv[]) {
        Initializer runner(argc, argv, OSQUERY_EXTENSION);
        runner.shutdown();
        return 0;
      }
    EOS

    system ENV.cxx, "test.cpp", "-o", "test", "-v", "-std=c++11",
      "-losquery", "-lthrift", "-lboost_system", "-lboost_thread-mt",
      "-lboost_filesystem", "-lglog", "-lgflags", "-lrocksdb"
    system "./test"
  end
end
