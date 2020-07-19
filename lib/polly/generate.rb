#

module Polly
  class Generate
    class << self 
      def get_binding
        binding
      end

      def output
        @output ||= StringIO.new # $stdout
      end

      #def command_list
      #  @command_list ||= []
      #end

      def read_output
        @output.rewind
        @output.read
      end

      #(job_run_name, docker_image, steps, job_env, working_directory)

      #def circleci_output
      #  @circleci_output ||= StringIO.new # $stdout
      #end

      def read_circleci_output
        #@circleci_output.rewind
        #@circleci_output.read
        #puts @plain_workflow

    #puts YAML.dump(@plain_workflow.all_jobs)
    #puts YAML.dump(@plain_workflow.deps)
    #puts "!!!"

#{
#"workflows"=>{
#  "version"=>2, 
#   "polly"=>{
#     "jobs"=>[]}},
#"version"=>2,
#"jobs"=>{}
#}

jobs_repacked = {}

@plain_workflow.all_jobs.each { |job_name, job_spec|
	jobs_repacked[job_name] = {
    "environment" => job_spec.parameters[:environment],
    "working_directory" => job_spec.parameters[:working_directory],
    "steps" => [
      {
        "run" => {
          "name" => job_spec.run_name,
          "command" => job_spec.parameters[:command]
        }
      }
    ]
  }.merge({
    "docker" => job_spec.parameters[:executor_hints][:docker]
  })
}

#bootstrap: !ruby/object:Polly::Job
#  run_name: bootstrap                              
#  parameters:                                                                                             
#    :environment:
#      CI: 'true'
#      CIRCLE_NODE_INDEX: '0'
#      CIRCLE_NODE_TOTAL: '1'
#      CIRCLE_SHA1:     
#      RACK_ENV: test
#      RAILS_ENV: test
#      CIRCLE_ARTIFACTS: "/var/tmp/artifacts"
#      CIRCLE_TEST_REPORTS: "/var/tmp/reports"
#      SSH_ASKPASS: 'false'
#      CIRCLE_WORKING_DIRECTORY: "/home/app/current"
#      PATH: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
#      TZ: Etc/UCT
#    :command: |2
#                                                     
#      echo BEGIN bootstrap
#      true                        
#                                                                                                          
#      echo END bootstrap                                                                                  
#    :working_directory:                                                                                   
#    :executor_hints:                                                                                      
#      :docker:                                                                                            
#      - image: ubuntu:latest                      
#primary: !ruby/object:Polly::Job                                                                                                                                                                                     
#  run_name: primary               
#  parameters:                                       
#    :environment:                                   
#      CI: 'true'                                                                                          
#      CIRCLE_NODE_INDEX: '0'                                                                              
#      CIRCLE_NODE_TOTAL: '1'
#      CIRCLE_SHA1:                                                                                        
#      RACK_ENV: test
#      RAILS_ENV: test                                                                                     
#      CIRCLE_ARTIFACTS: "/var/tmp/artifacts"
#      CIRCLE_TEST_REPORTS: "/var/tmp/reports"                                                             
#      SSH_ASKPASS: 'false'                                                                                                                                                                                           
#      CIRCLE_WORKING_DIRECTORY: "/home/app/current"
#      PATH: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
#      TZ: Etc/UCT
#    :command: |2
#
#      echo BEGIN rspec
#      bundle exec rspec
#
#      echo END rspec
#    :working_directory: 
#    :executor_hints:
#      :docker:
#      - image: polly:latest
#jobs:
#  primary:
#		docker:
#			- image: &build_image ubuntu:bionic-20180526
#    steps:
#      - checkout
#
#      - run:
#          name: bootstrap
#nil
#workflows:
#  version: 2
#    build:
## example
#
# bootstrap: []
# primary:
# - bootstrap
#     - bootstrap
# =>
# - bootstrap:
#     requires: []
# - primary:
#     requires:
#     - bootstrap
## example
#
#  bootstrap:
#    docker:
#      - image: &bootstrap_build_image ubuntu:latest
#    steps:
#      - run:
#          name: bootstrap
        
###TODO: debug File.read("spec/fixtures/dot-circleci/config.yml")

#puts @plain_workflow.deps.inspect
#raise "Wtf"

output_circleci = {
  "workflows" => {
    "version" => 2,
    "polly" => {
      "jobs" => @plain_workflow.deps.collect { |k, v| {k => {"requires" => v}} }
    }
  },
  "version" => 2,
  "jobs" => jobs_repacked
}
      end

      def emit(bytes)
        output.write(bytes)
      end

      def command(c)
        emit c + " "
        emit yield if block_given?
        emit $/
      end

      def comment(s)
        command("#") {
          s
        }
      end

      def run(s)
        @command_list << s

        command("RUN") {
          "--mount=type=ssh,uid=1000,gid=1000,mode=741 set -ex; " + s
        }
      end

      def apt(p)
        run "apt-get update" +
            "; apt-get install -y " +
              p.join(" ") +
            "; apt-get clean; rm -rf /var/lib/apt/lists/*"
      end

      def ppa(r)
        run "apt-add-repository ppa:" + r
      end

      def image(type = :dockerfile)
        @command_list = []

        comment "syntax=docker/dockerfile-upstream:master-experimental"

        yield

        comment "Generated #{Time.now}"

        OpenStruct.new(:stage => @image_name, :command_list => @command_list)
      end

      def stage(name, from)
        @image_name = name
        command("FROM #{from} AS #{name}")
      end

      def env(h)
        emit "ENV"
        h.each { |k,v|
          emit(" " + k + "=" + v)
        }
        emit $/
      end
    end
  end

  class Task
  end
end

#@all_jobs = {}
#@jobs_by_dependency = {}
#@current_job = nil
#
#def run(shell_task, shell_code)
#  puts "echo #{shell_task}"
#  puts shell_code
#  @current_job["code"] ||= {}
#  @current_job["code"][shell_task] = shell_code.strip
#end
#
#def job(name, dependencies = [])
#  name = name.to_s
#
#  puts [name, dependencies].inspect
#  new_job = {
#    "meta" => { "dependencies" => dependencies.map(&:to_s) }
#  }
#
#  dependencies.each do |dependency|
#    dependency = dependency.to_s
#    @jobs_by_dependency[dependency] ||= []
#    @jobs_by_dependency[dependency] << name
#  end
#
#  @current_job = new_job
#
#  @all_jobs[name] = new_job
#
#  yield
#end
#
#def workflows(workflow_name)
#  puts workflow_name.inspect
#  yield
#
#  puts YAML.dump(@all_jobs)
#end
#
#def trigger(env = {})
#  #sha, commit_description, npm_token, 
#  puts "makes a pipeline"
#  puts YAML.dump(@all_jobs)
#
#  resources => [
#    {
#      "name" => "my-repo",
#      "type" => "git"
#    },
#    {
#      "name" => "my-image"
#      "type" => "image"
#    }
#  ]
#
#  tasks = []
#
#  pipeline = {
#    "apiVersion" => "tekton.dev/v1alpha1",
#    "kind" => "Pipeline",
#    "metadata" => {
#    },
#    "spec" => {
#      "tasks" => tasks
#    }
#  }
#
#  puts "makes a pipelinerun"
#  # TODO
#end
