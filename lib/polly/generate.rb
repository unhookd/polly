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

      def read_output
        if @output
          @output.rewind
          @output.read
        end
      end

      def all_images
        @all_images
      end

      def read_circleci_output(ident = nil)
        jobs_repacked = {}

        @pl_wk = ident.nil? ? @workflows_by_ident[@workflows_by_ident.keys.first] : @workflows_by_ident[ident]

        @pl_wk.all_jobs.each { |job_name, job_spec|
          jobs_repacked[job_name] = {
            "environment" => job_spec.parameters[:environment],
            "working_directory" => job_spec.parameters[:working_directory],
            "steps" => [
              "checkout",
              (job_name.include?("bootstrap") ? {"setup_remote_docker" => { "version" => "19.03.12" }} : nil),
              {
                "run" => {
                  "name" => job_spec.run_name,
                  "command" => job_spec.parameters[:command].strip
                }
              }
            ].compact
          }.merge({
            "docker" => job_spec.parameters[:executor_hints][:docker]
          })
          jobs_repacked[job_name].delete("environment") unless jobs_repacked[job_name]["environment"] && !jobs_repacked[job_name]["environment"].empty?
          jobs_repacked[job_name].delete("working_directory") unless jobs_repacked[job_name]["working_directory"]
        }

        output_circleci = {
          "workflows" => {
            "version" => 2,
            "polly" => {
              "jobs" => @pl_wk.deps.collect { |k, v| {k => {"requires" => v}} }
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
        emit c
        if block_given?
          emit " "
          emit yield
        end
        emit $/
      end

      def comment(s)
        command("#") {
          s
        }
      end

      def description(s) # adds annotation for github packages
        command("LABEL") {
          "org.opencontainers.image.description #{s}"
        }
      end

      def run(s)
        @command_list << s

        cache_sweep = (
          @last_known_user == "root" ? "; rm -Rf /var/log/* /var/lib/gems/**/cache/*.gem /var/lib/gems/**/*.out /etc/machine-id /var/lib/dbus/machine-id /var/cache/ldconfig/aux-cache /run/systemd/resolve/stub-resolv.conf" : ""
        )

        command("RUN") {
          "--mount=type=ssh,uid=1000,gid=1000,mode=741 set -ex; " + s + cache_sweep
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

      def user(u)
        @last_known_user = u
        command("USER") {
          u
        }
      end

      def root
        user("root")
      end

      def app
        user("app")
      end

      def prototype1
        @prototype1 = true
        @bootstrap = image {
          stage "bootstrap", "ubuntu:focal-20210827"
          root
          apt %w{curl mysql-client-8.0 mysql-server-core-8.0 ruby2* libruby2* ruby-bundler rubygems-integration rake git build-essential default-libmysqlclient-dev}
          run %q{useradd --uid 1000 --home-dir /home/app --create-home --shell /bin/bash app}
          command("WORKDIR") {
            "/home/app"
          }
        }
        @deploy = image {
          stage "deploy", @bootstrap.stage
          app
          run %q{mkdir -p ~/.ssh}
          run %q{ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts}
          run %q{bundle config set --local path /home/app/vendor/bundle}
          run %q{bundle config set --local jobs 4}
          run %q{bundle config set --local retry 3}
          #TODO: figure out conventional bundling strategy
          #run %q{bundle config set --local deploment true}
          #run %q{bundle config set --local without development}
          command("COPY") {
            "--chown=app Gemfile VERSION *.gemspec /home/app"
          }
          command("COPY") {
            "--chown=app bin /home/app/bin"
          }
          run %q{bundle install}
          command("COPY") {
            "--chown=app . /home/app"
          }
        }
      end

      def prototype2
        @prototype2 = true
        @bootstrap = image {
          stage "bootstrap", "node:16.18-bullseye"
          root
          #apt %w{curl mysql-client-8.0 mysql-server-core-8.0 ruby2* libruby2* ruby-bundler rubygems-integration rake git build-essential default-libmysqlclient-dev}
          run %q{useradd --uid 1001 --home-dir /home/app --create-home --shell /bin/bash app}
          command("WORKDIR") {
            "/home/app"
          }
        }
        @deploy = image {
          stage "deploy", @bootstrap.stage
          app
          run %q{mkdir -p ~/.ssh}
          run %q{ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts}

          command("COPY") {
            "--chown=app package.json VERSION /home/app"
          }
          run %q{npm install}

          command("COPY") {
            "--chown=app Folderfile.example client.js infc.js style.css doc /home/app/"
          }
        }
      end

      def prototype_wkndr
        @prototype_wkndr = true
        @deploy = image {
          stage "bootstrap", "wkndr:latest"
          env("FOO" => Time.now.to_f.to_s)
          run %q{rm -Rf /var/lib/wkndr/public}
          #run %q{mkdir -p /var/lib/wkndr/public}
          command("COPY") {
            "Wkndrfile /var/lib/wkndr/"
          }
          env("FOO" => Time.now.to_f.to_s)
          command("COPY") {
            "--chown=app public /var/lib/wkndr/public"
          }
          #command("COPY") {
          #  "--chown=app public/index.html /var/lib/wkndr/public/"
          #}
          #run %q{/var/lib/wkndr/iterate-web.sh}
          run %q{cat /var/lib/wkndr/public/index.html || true}
          run %q{cat /var/lib/wkndr/Wkndrfile}
          run %q{ls -l /var/lib/wkndr/public}
        }
      end

      def image(type = :dockerfile)
        @command_list = []

        comment "syntax=docker/dockerfile-upstream:master-experimental"

        yield

        #comment "Generated #{Time.now}"

        new_image = OpenStruct.new(:stage => @image_name, :from => @image_from, :command_list => @command_list)
        @all_images ||= []
        @all_images << new_image
        new_image
      end

      def stage(name, from)
        @image_name = name
        @image_from = from
        command("FROM #{from} AS #{name}")
      end

      def env(h)
        emit "ENV"
        h.each { |k,v|
          export = " " + k + "=" + v
          emit(export)
          @command_list << "export #{export}"
        }
        emit $/
      end

      def job(*args)
        @this_plan.add_circleci_job(*args)
      end

      def plan
        @workflows_by_ident ||= {}

        @this_plan = Plan.new

        yield

        @workflows_by_ident[@this_plan.ident] = @this_plan

        @this_plan
      end

      #TODO: build detachable build pipeline bits???
      def continuous
        @shell_commands ||= []
        yield
      end

      def test(plan)
        @shell_commands << ["polly", "test", "--ident", plan.ident]
      end

      def read_shell_commands
        @shell_commands.collect! { |shell_cmd_array|
          shell_cmd_array.join(" ")
        }.join("; ")
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




      #def command_list
      #  @command_list ||= []
      #end

      #(job_run_name, docker_image, steps, job_env, working_directory)

      #def circleci_output
      #  @circleci_output ||= StringIO.new # $stdout
      #end

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
