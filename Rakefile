# frozen_string_literal: true

require "bundler/gem_tasks"
require "rbconfig"
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

  desc "Verify optional compressed audio backend detection without PATH tools"
  task :optional_backends do
    require_relative "lib/deftones"

    previous_path = ENV["PATH"]
    previous_backend = Deftones::IO::Buffer.codec_backend
    ENV["PATH"] = ""
    Deftones::IO::Buffer.codec_backend = nil
    raise "Compressed audio backend should be unavailable without PATH tools" if Deftones.compressed_audio_available?
  ensure
    Deftones::IO::Buffer.codec_backend = previous_backend if defined?(Deftones::IO::Buffer)
    ENV["PATH"] = previous_path
  end

  desc "Verify the library loads cleanly with Ruby warnings enabled"
  task :require_warnings do
    ruby = RbConfig.ruby
    sh ruby, "-w", "-Ilib", "-e", "require 'deftones'; puts Deftones.version"
  end
end

task quality: ["quality:gem_files", "quality:optional_backends", "quality:require_warnings"]
task default: %i[spec quality]
