#!/usr/bin/env ruby

dir = File.expand_path("../..", __FILE__)
$:.unshift File.join(dir, "lib")
ENV["BUNDLE_GEMFILE"] = File.join(dir, "Gemfile")

require "bundler/setup"
require "benchmark"

Benchmark.bm do |b|
  b.report %[require "optimism"] do
    require "optimism"
  end
end
