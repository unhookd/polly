#

version = File.read(File.expand_path("VERSION", __dir__)).strip

Gem::Specification.new do |spec|
  spec.name          = "polly"
  spec.version       = version
  spec.authors       = ["Jon Bardin", "Jack Senechal"]
  spec.email         = ["diclophis@gmail.com", "jacksenechal@gmail.com"]

  spec.summary       = %q{FOO}
  spec.description   = %q{BAR}
  spec.homepage      = "https://unctl.io/"
  spec.license       = "MIT"

  spec.files         = ["Thorfile", "polly.gemspec", "VERSION", "CHANGELOG"] + Dir.glob("lib/**/*")
  spec.bindir        = ["bin"]
  spec.executables   = ["polly"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "= 0.20.3"
  spec.add_dependency "net-ssh", "~> 6.0"
  spec.add_dependency "yajl-ruby", "= 1.4.1"
  spec.add_dependency "guard", "~> 2.18"
end
