# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "suj/pusher/version"

Gem::Specification.new do |s|
  s.name        = "suj-pusher"
  s.version     = Suj::Pusher::VERSION
  s.authors     = ["Horacio Sanson / Fernando Wong / Nicolas Bersano(WNS and MPNS support)"]
  s.email       = ["rd@skillupjapan.co.jp, n.bersano@skillupchile.cl"]
  s.homepage    = "https://github.com/sujrd/suj-pusher"
  s.summary     = %q{Stand alone push notification server.}
  s.description = %q{Stand alone push notification server for APN, GCM, WNS and MPNS.}

  s.files         = `git ls-files -- lib README.md CHANGELOG.md LICENSE`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features,config}`.split("\n")
  s.executables   = `git ls-files -- bin`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "em-http-request"
  s.add_dependency "em-hiredis"
  s.add_dependency "multi_json"
  s.add_dependency "daemon-spawn"
end
