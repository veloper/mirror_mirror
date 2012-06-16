# -*- encoding: utf-8 -*-
require File.expand_path('../lib/mirror_mirror/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Daniel Doezema"]
  gem.email         = ["dan@doezema.com"]
  gem.description   = %q{Allows an ActiveRecord model to mirror an external REST resource.}
  gem.summary       = %q{Allows an ActiveRecord model to mirror an external REST resource.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "mirror_mirror"
  gem.require_paths = ["lib"]
  gem.version       = MirrorMirror::VERSION
end
