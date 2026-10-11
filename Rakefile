# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create do |t|
  # Solargraph and its dependencies emit many -w warnings on Ruby 4.0.
  t.warning = false
end

require "standard/rake"

task default: %i[test standard]
