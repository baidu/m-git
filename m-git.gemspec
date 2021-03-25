
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "m-git/version"

Gem::Specification.new do |spec|
  spec.name          = "m-git"
  spec.version       = MGit::VERSION
  spec.authors       = ["zhangyu81"]
  spec.summary       = %q{A multi-repository management tool integrated with git.}
  spec.description   = %q{A multi-repository management tool integrated with git. for detail see home page}
  spec.homepage      = "https://github.com/baidu/m-git"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/baidu/m-git/tree/master"
    spec.metadata["changelog_uri"] = "https://github.com/baidu/m-git/tree/master/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
  #   `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  # end
  spec.files         = %w(README.md LICENSE) + Dir['lib/**/*.rb']
  spec.bindir        = "./"
  spec.executables   = %w(mgit m-git)
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'colored2', '~> 3.1'
  spec.add_runtime_dependency 'peach', '~> 0.5'
  spec.add_runtime_dependency 'tty-pager', '~> 0.12'

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", '~> 5.14.1'
  spec.add_development_dependency "minitest-reporters", '~> 1.4.2'

  spec.required_ruby_version = '>= 2.3.0'
end
