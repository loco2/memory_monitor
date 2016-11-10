# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'memory_monitor/version'

Gem::Specification.new do |spec|
  spec.name          = "memory_monitor"
  spec.version       = MemoryMonitor::VERSION
  spec.authors       = ["Jon Leighton"]
  spec.email         = ["jon@loco2.com"]

  spec.summary       = %q{Restart a process when memory usage is too high}
  spec.description   = %q{Restart a process when memory usage is too high}
  spec.homepage      = "https://github.com/loco2/memory_monitor"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
