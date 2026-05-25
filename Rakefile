# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

namespace :quality do
  desc "Verify gem package file boundaries"
  task :gem_files do
    spec = Gem::Specification.load("deftones.gemspec")
    forbidden_prefixes = %w[.github/ spec/ build/ pkg/]
    forbidden_files = spec.files.select { |file| forbidden_prefixes.any? { |prefix| file.start_with?(prefix) } }
    raise "Unexpected files in gem: #{forbidden_files.join(', ')}" unless forbidden_files.empty?

    large_files = spec.files.select { |file| File.file?(file) && File.size(file) > 1_000_000 }
    raise "Large files in gem: #{large_files.join(', ')}" unless large_files.empty?
  end
end

task quality: ["quality:gem_files"]
task default: %i[spec quality]
