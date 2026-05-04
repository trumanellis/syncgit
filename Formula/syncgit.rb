class Syncgit < Formula
  desc "Peer-worktree git sync for AI agents collaborating on shared code"
  homepage "https://github.com/trumanellis/syncgit"
  url "https://github.com/trumanellis/syncgit/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER_FILL_ON_RELEASE"
  license "MIT"
  head "https://github.com/trumanellis/syncgit.git", branch: "main"

  depends_on "bash"
  depends_on "git"
  depends_on "python@3"

  def install
    # lib.sh is sourced as "$here/lib.sh" where $here is the bin directory,
    # so both files must land in the same prefix bin dir.
    bin.install "bin/syncgit", "bin/lib.sh"
    pkgshare.install "commands"
    pkgshare.install "examples" if File.directory?("examples")
    pkgshare.install "VERSION" if File.exist?("VERSION")
    doc.install "README.md", "CHANGELOG.md", "LICENSE"
  end

  test do
    assert_match "syncgit", shell_output("#{bin}/syncgit --version")
    system "#{bin}/syncgit", "help"
  end
end
