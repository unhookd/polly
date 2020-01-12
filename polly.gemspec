#

Gem::Specification.new do |spec|
  spec.name          = "polly"
  spec.version       = "1.0.0"
  spec.authors       = ["Jon Bardin", "Jack Senechal"]
  spec.email         = ["diclophis@gmail.com", "jacksenechal@gmail.com"]

  spec.summary       = %q{FOO}
  spec.description   = %q{BAR}
  spec.homepage      = "https://unctl.io/"
  spec.license       = "MIT"

  spec.files         = ["Thorfile"] + Dir.glob("lib/**/*")
  spec.bindir        = ["bin"]
  spec.executables   = ["polly"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 0.20"

  spec.add_dependency "yajl-ruby", "~> 1.4"
end
