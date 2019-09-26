#

require 'rspec'

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'polly'

RSpec.configure do |c|
  c.before :each do
  end
end
