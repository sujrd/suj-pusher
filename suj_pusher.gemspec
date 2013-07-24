# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "suj/pusher/version"

Gem::Specification.new do |s|
  s.name        = "suj_pusher"
  s.version     = Suj::Pusher::VERSION
  s.authors     = ["Horacio Sanson"]
  s.email       = ["rd@skillupjapan.co.jp"]
  s.homepage    = "https://github.com/sujrd/suj-pusher"
  s.summary     = %q{Stand alone push notification server.}
  s.description = %q{Stand alone push notification server for APN and GCM.}

  s.files         = `git ls-files -- lib README.md CHANGELOG.md LICENSE`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features,config}`.split("\n")
  s.executables   = `git ls-files -- bin`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "rapns", "~> 3.3.2"
end
