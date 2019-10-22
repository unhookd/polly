require 'yaml'
require 'open3'
require 'json'
require 'tempfile'
require 'strscan'
require 'date'

module Polly
  POLLY = "polly"
  VERSION = "0.1.0"

  class Error < StandardError; end

  autoload 'Plan', 'polly/plan'
  autoload 'Execute', 'polly/execute'
  autoload 'Job', 'polly/job'
  autoload 'Observe', 'polly/observe'
end
