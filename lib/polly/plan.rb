#

module Polly
  class Plan
    DEFAULT_CONCURRENCY = 1
    DEFAULT_CIRCLECI_CONFIG_YML_PATH = ".circleci/config.yml"

    attr_accessor :all_jobs
    attr_accessor :deps

    def initialize(revision = nil, upto_these_jobs = nil, options = {})
      @all_jobs = {}
      @upto_these_jobs = begin
        if upto_these_jobs
          Array(upto_these_jobs.split(":"))
        else
          []
        end
      end

      @revision = revision
      @dry_run = options["dry-run"]
      @debug = options["debug"]
      @bootstrap = options["bootstrap"]
      @concurrency = options["concurrency"] || DEFAULT_CONCURRENCY
      @jobs_to_skip = begin
        if skip = options["skip"]
          Array(skip.split(":"))
        else
          []
        end
      end

      @only_these_jobs = begin
        if only = options["only"]
          Array(only.split(":"))
        else
          []
        end
      end

      @deps = {}
      @completed = {}
      @started = {}

      @iteration = 0

      @pwd = Dir.pwd
    end

    def description
      "the plan is as follows: #{self}"
    end

    def add_job(job)
      raise "invalid job" unless job.valid?

      @all_jobs[job.run_name] = job
      @deps[job.run_name] = []
    end

    def depends(left_job_run_name, right_job_run_name)
      #TODO: left_job_run_name.is_a?(Job) ...
      @deps[left_job_run_name] ||= []
      @deps[left_job_run_name] << right_job_run_name
    end

    def has_unfinished_jobs?
      a = (jobs_ready_to_start(true) != :deadend)
      b = !(@all_jobs.keys - @completed.keys).empty?
      a && b
    end

    def prune!
      unless @pruned
        @pruned = true

        jobs_to_prune = []

        is_dep_of = lambda { |this_job, target|
          if @deps[target] && target_deps = @deps[target]
            if target_deps.include?(this_job)
              dop = true
              dop
            else
              dop = target_deps.any? { |tdep|
                is_dep_of.call(this_job, tdep)
              }
              dop
            end
          end
        }

        @all_jobs.keys.each { |job_run_name|
          @upto_these_jobs.each { |upto_this_run_name|
            if (job_run_name != upto_this_run_name) && !@upto_these_jobs.include?(job_run_name)
              unless is_dep_of.call(job_run_name, upto_this_run_name)
                jobs_to_prune << job_run_name
              end
            end
          }
        }

        jobs_to_prune.reject! { |jprune|
          @upto_these_jobs.any? { |tj|
            is_dep_of.call(jprune, tj)
          }
        }
        
        jobs_to_prune.uniq!

        if @debug
          puts [:prune, jobs_to_prune].inspect unless jobs_to_prune.empty?
        end

        jobs_to_prune.each { |job_to_prune_run_name|
          prune_job!(@all_jobs[job_to_prune_run_name])
        }
      end
    end

    def skip_job!(job)
      start_job!(job)
      complete_job!(job)
    end

    def start_job!(job)
      @started[job.run_name] = true
    end

    def prune_job!(job)
      @all_jobs.delete(job.run_name)
      @deps.delete(job.run_name)
    end

    def skip_jobs!
      jobs_skipped = []

      @all_jobs.keys.each { |job_run_name|
        if @jobs_to_skip.include?(job_run_name) || (!@only_these_jobs.empty? && !@only_these_jobs.include?(job_run_name))
          skip_job!(@all_jobs[job_run_name])
          jobs_skipped << job_run_name
        end
      }

      if @debug
        puts [:skipped, jobs_skipped].inspect unless jobs_skipped.empty?
      end
    end

    def jobs_ready_to_start(peek_only = false)
      @iteration += 1

      prune!

      skip_jobs!

      # collect all jobs with zero pending reqs
      jobs_with_zero_req = []
      jobs_with_failed_req = []

      @deps.each do |job, reqs|
        if !reqs || reqs.all? { |required_job_run_name| @completed[required_job_run_name] }
          jobs_with_zero_req << job
        end

        if reqs && reqs.any? { |required_job_run_name| @completed[required_job_run_name] == false }
          jobs_with_failed_req << job
          @started[job] = true
          @completed[job] = false
        end
      end

      # remove completed, or started, or skipped jobs
      jobs_with_zero_req.reject! { |job_run_name| @started.key?(job_run_name) || @completed.key?(job_run_name) }

      count_of_running_jobs = @started.count - @completed.count

      if peek_only
        a = @all_jobs.keys
        b = (jobs_with_failed_req + @completed.keys)
        if (a - b).empty?
          return :deadend
        end
      else
        jobs_with_zero_req.slice(0, @concurrency - count_of_running_jobs).map { |job_run_name|
          raise "not should ever happen, you found a bug" unless @all_jobs[job_run_name]

          @started[job_run_name] = true
          @all_jobs[job_run_name]
        }.compact
      end
    end

    def complete_job!(job)
      @completed[job.run_name] = !job.failed?
    end

    #TODO: enhance support for known circleci templates
    def load_circleci(raw_yaml = File.read(DEFAULT_CIRCLECI_CONFIG_YML_PATH))
      raise "empty config" if raw_yaml.nil? || raw_yaml.empty?

      yaml_template_rendered = raw_yaml.gsub("$CIRCLE_SHA1", @revision)
      circle_yaml = YAML.load(yaml_template_rendered)

      return unless circle_yaml && circle_yaml["workflows"] && circle_yaml["jobs"]

      add_job_to_stack = lambda { |job_run_name|
        circleci_like_parameters = circle_yaml["jobs"][job_run_name]
        image = nil

        if exe_found = circleci_like_parameters["executor"]
          exe_name = exe_found["name"]
          if exe_name
            image = circle_yaml["executors"][exe_name]["docker"]
          else
            image = circle_yaml["executors"][exe_found]["docker"]
          end
        else
          image = circleci_like_parameters["docker"]
        end

        puts "add_circleci_job(#{job_run_name}, #{image}, #{circleci_like_parameters["steps"]}, #{circleci_like_parameters["environment"]}, #{circleci_like_parameters["working_directory"]}"
        add_circleci_job(job_run_name, image, circleci_like_parameters["steps"], circleci_like_parameters["environment"], circleci_like_parameters["working_directory"])
      }

      circle_yaml["workflows"].each do |workflow_key, workflow|
        #TODO: check for compat version in future...
        next if workflow_key == "version"

        workflow["jobs"].each do |job_run_name_or_reqs|
          if job_run_name_or_reqs.is_a?(String)
            job_run_name = job_run_name_or_reqs
            add_job_to_stack.call(job_run_name)
          else
            job_run_name = job_run_name_or_reqs.keys.first
            if add_job_to_stack.call(job_run_name)
              if job_run_name_or_reqs[job_run_name]
                job_run_name_or_reqs[job_run_name]["requires"].each { |dep_job_run_name|
                  puts "depends(#{job_run_name}, #{dep_job_run_name})"
                  depends(job_run_name, dep_job_run_name)
                }
              end
            end
          end
        end
      end
    end

    def add_circleci_job(job_run_name, docker_image, steps, job_env, working_directory)
      executor_hints = {
        :docker => docker_image
      }

      #steps = circleci_like_parameters["steps"]

      pro_fd = StringIO.new

      count_of_steps = 0

      steps.each_with_index do |step, step_index|
        if step == "checkout"
          executor_hints[:checkout] = true
          next
        end

        if step == "setup-remote-docker" || step == "setup_remote_docker"
          executor_hints[:setup_remote_docker] = true
          next
        end

        if run = step["run"]
          name = run["name"]

          pro_fd.write("\necho BEGIN #{name}\n")
          pro_fd.write(run["command"])
          pro_fd.write("\necho END #{name}\n")

          count_of_steps += 1

          next
        end
      end

      pro_fd.rewind

      circleci_env = {
        #"CI" => "true",
        #"CIRCLE_NODE_INDEX" => "0",
        #"CIRCLE_NODE_TOTAL" => "1",
        #"FART" => "farts",
        #"RACK_ENV" => "test",
        #"RAILS_ENV" => "test",
        #"CIRCLE_ARTIFACTS" => "/var/tmp/artifacts",
        #"CIRCLE_TEST_REPORTS" => "/var/tmp/reports",
        #"SSH_ASKPASS" => "false",
        #"CIRCLE_WORKING_DIRECTORY" => "/home/app/current",
        #"PATH" => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games",
        ##TODO: parse all of the executor models
        #"TZ" => "Etc/UCT",
        #"SSH_AUTH_SOCK" => ENV["SSH_AUTH_SOCK"]
        #TODO: "HTTP_PROXY_HOST" => "#{http_proxy_service_ip}:8111"
      }

      if @revision && !@revision.empty?
        circleci_env["CIRCLE_SHA1"] = @revision
      end

      if job_env
        circleci_env.merge!(job_env)
      end

      valid_parameters = {
        :environment => circleci_env,
        :command => pro_fd.read,
        :working_directory => working_directory,
        :executor_hints => executor_hints
      }

      if count_of_steps > 0
        new_job = Job.new(job_run_name, valid_parameters)
        add_job(new_job)
      end
    end
  end
end
