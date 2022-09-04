require_relative 'lib/scale_rb_2/version'

Gem::Specification.new do |spec|
  spec.name          = 'scale_rb_2'
  spec.version       = ScaleRb2::VERSION
  spec.authors       = ['Aki Wu']
  spec.email         = ['aki.wu@itering.com']

  spec.summary       = 'Ruby SCALE Codec Library'
  spec.description   = 'Ruby implementation of the parity SCALE data format'
  spec.homepage      = 'https://github.com/wuminzhe/scale.rb.2'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6.0')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
