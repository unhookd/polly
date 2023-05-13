#

module Polly
  class Job
    #NOTE: these are what make a job valid
    #
    # run_name is the name of the job
    #   :run_name => "package-container"
    #
    # parameters are the shape and characterstics of the job
    #   :parameters => {
    #     :command => "true && false",
    #     :working_directory => "/home/app/current"
    #     :environment => {
    #       CUSTOM: "config"
    #     }
    #     :docker_executor_hints => {
    #       - image: user-customized-ubuntu:tagged-latest
    #     }
    #   }
    #
    attr_accessor :run_name
    attr_accessor :parameters

    def initialize(run_name = nil, parameters = {})
      @run_name = run_name
      @parameters = parameters
    end

    def to_json(*args)
      [@run_name, @parameters].to_json(*args)
    end

    def valid?
      #TODO: more validation
      !!(@run_name && !@run_name.empty?)
    end

    def failed?
      @failed
    end

    def fail!
      @failed = true
    end
  end
end
