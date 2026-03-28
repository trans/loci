require "spec"
require "file_utils"
require "../src/loci"

TEST_PROJECT_DIR = "spec/test_project"

def with_test_project(&)
  FileUtils.rm_rf(TEST_PROJECT_DIR)
  Dir.mkdir_p(File.join(TEST_PROJECT_DIR, "src"))
  begin
    yield TEST_PROJECT_DIR
  ensure
    FileUtils.rm_rf(TEST_PROJECT_DIR)
  end
end
