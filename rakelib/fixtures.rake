# frozen_string_literal: true

require "fileutils"
require "tmpdir"

TALON_REPO = "https://github.com/asimmons91/talon.git"
TALON_FIXTURE = File.expand_path("../test/fixtures/talon", __dir__)

namespace :fixtures do
  desc "Re-vendor Talon's lib/ into test/fixtures/talon from a branch, tag or commit (default: main)"
  task :sync, [:ref] do |_task, args|
    ref = args[:ref] || "main"
    Dir.mktmpdir do |dir|
      sh "git", "-C", dir, "init", "--quiet"
      sh "git", "-C", dir, "fetch", "--quiet", "--depth", "1", TALON_REPO, ref
      sh "git", "-C", dir, "checkout", "--quiet", "FETCH_HEAD"
      commit = `git -C #{dir} rev-parse HEAD`.strip

      FileUtils.rm_rf(Dir[File.join(TALON_FIXTURE, "*")] - [File.join(TALON_FIXTURE, "UPSTREAM")])
      FileUtils.cp_r(Dir[File.join(dir, "lib", "*")], TALON_FIXTURE)
      upstream = File.read(File.join(TALON_FIXTURE, "UPSTREAM")).sub(/\b\h{40}\b/, commit)
      File.write(File.join(TALON_FIXTURE, "UPSTREAM"), upstream)
      puts "Synced test/fixtures/talon to #{commit}. Run `bundle exec rake test` to check the plugin against it."
    end
  end
end
