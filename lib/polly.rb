if Dir.exists?(File.expand_path("../.bundle", __dir__))
  ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

  require "bundler/setup" # Set up gems listed in the Gemfile.
end

require 'thor'

require 'yaml'
require 'open3'
require 'json'
require 'tempfile'
require 'strscan'
require 'date'
require 'openssl'
require 'base64'
require 'expect'
require 'uri'
require 'pathname'
require 'fileutils'
require 'net/ssh'

module Polly
  POLLY = "polly"

  class Error < StandardError; end

  autoload 'Build', 'polly/build'
  autoload 'Config', 'polly/config'
  autoload 'Execute', 'polly/execute'
  autoload 'Generate', 'polly/generate'
  autoload 'Job', 'polly/job'
  autoload 'Observe', 'polly/observe'
  autoload 'Plan', 'polly/plan'
end
