# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "feature_flags/version"

Gem::Specification.new do |s|
  s.name = "feature_flags"
  s.version = FeatureFlags::VERSION
  s.authors = ["Althaf Hameez"]
  s.email       = ["althaf.hameez@grabtaxi.com"]
  s.description = "Feature Flags using redis"
  s.summary = "Feature flags using redis"
  s.homepage = "https://github.com/myteksi/feature_flags"

  s.require_paths = ["lib"]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec", "3.3.0"
  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "jeweler", "~> 1.6.4"
  s.add_development_dependency "bourne", "1.0"
  s.add_development_dependency "mocha", "0.9.8"
  s.add_development_dependency "fakeredis"

  s.add_runtime_dependency "redis"
end
