#

module Polly
  class Execute
    DEFAULT_IDLE_TIMEOUT = 3600

    def initialize(options = {})
      @idle_timeout = options["idle-timeout"] || DEFAULT_IDLE_TIMEOUT
      @image_override = options["with-bootstrap"]
      @dry_run = options["dry-run"]
      @keep_completed = options["keep-completed"]
      @detach_failed = options["detach-failed"]
      @short_circuit = options["short-circuit"]
      @debug = options["debug"]
      @init = !options["no-init"]

      @running_jobs = {}
      @runners = []
      @iteration = 0

      #TODO: better safety checks
      check_current_kube_context_is_safe!

      @exiting = false
      trap 'INT' do
        @exiting = true
      end
    end

    def description
      "the executor is #{self}"
    end

    def system(*args)
      Kernel.system(*args)
    end

    def systemx(*cmd)
      #pid = Kernel.spawn(*cmd)
      #status = Process.wait pid
      status = Kernel.system(*cmd)
      unless status
        Kernel.exit(1)
      end
    end

    def check_current_kube_context_is_safe!
      current_kube_context = IO.popen("kubectl config current-context").read.strip
      wait_child
      raise "unsafe kubernetes context" unless Polly::Config.allowed_contexts.include?(current_kube_context)
    end

    def current_revision
      @revision ||= begin
        #TODO: handle error cases
        current_sha = IO.popen("git rev-parse --verify HEAD").read.strip
        wait_child
        current_sha
      end
    end

    def current_app
      @current_app ||= begin
        File.basename(Dir.pwd).gsub(/[^a-z0-9\-\.]/, "") #TODO: better dirname support??
      end
    end

    def current_branch
      @current_branch ||= begin
        a = IO.popen("git rev-parse --abbrev-ref HEAD").read.strip
        wait_child
        a
      end
    end

    def start_job!(job)
      clean_name = (current_app + "-" + job.run_name).gsub(/[^\.a-z0-9]/, "-")[0..34]

      executor_hints = job.parameters[:executor_hints]

      #TODO: move to job validation???
      unless (executor_hints && executor_hints[:docker] && executor_hints[:docker].is_a?(Array)) || @image_override
        #TODO: raise exceptions
        $stderr.puts "req'd docker key missing" 
        Kernel.exit(1)
      end

      run_image = @image_override || begin
        first_docker_executor_hint = executor_hints[:docker].first

        unless first_docker_executor_hint
          #TODO: raise exceptions
          $stderr.puts "missing req'd docker image executor hint"
          Kernel.exit(1)
        end

        docker_image_url = URI.parse("http://local/#{first_docker_executor_hint["image"]}")
        repo = docker_image_url.host
        File.basename(docker_image_url.path)
      end

      build_run_dir = "/var/tmp/run"
      build_manifest_dir = File.join(build_run_dir, clean_name, current_revision)
      run_shell_path = File.join(build_manifest_dir, "run.sh")

      sleep_cmd_args = ["sleep", "infinity"]
      #TODO: figure out fail modes run_cmd_args = ["bash", "-x", "-e", "-o", "pipefail", run_shell_path]
      run_cmd_args = ["bash", "-e", "-o", "pipefail", "-c", "bash -e -o pipefail #{run_shell_path} > /proc/1/fd/1 2> /proc/1/fd/2"]

      #debug_cmd_args = ["cat", run_shell_path]
      #if @dry_run
      #elsif executor_hints[:detach]
      #else
      #end

      deployment_spec = {
        "apiVersion" => "apps/v1",
        "kind" => "Deployment",
        "metadata" => {
          "name" => clean_name,
          "labels" => {
            "app" => clean_name
          }
        },
        "spec" => {
          "revisionHistoryLimit" => 1,
          "strategy" => {
            "type" => "Recreate"
          },
          "replicas" => 1,
          "selector" => {
            "matchLabels" => {
              #TODO: abstract this!!!!
              "name" => clean_name
            }
          },
          "template" => {
            "metadata" => {
              "labels" => {
                #TODO: abstract this
                "name" => clean_name
              },
              "annotations" => {}
            }
          }
        }
      }

      container_spec = {
        ##TODO: converge this with workstion git context
        #"initContainers" => [
        #  {
        #    #"terminationGracePeriodSeconds" => 5,
        #    "name" => "git-clone",
        #    "image" => "polly:latest",
        #    "imagePullPolicy" => "IfNotPresent",
        #    "args" => [
        #      "polly", "checkout", "http://polly-app:8080/#{current_app}", current_revision, "/home/app/current"
        #    ],
        #    "env" => { "GIT_DISCOVERY_ACROSS_FILESYSTEM" => "true" }.collect { |k,v| {"name" => k, "value" => v } },
        #    "securityContext" => {
        #      "runAsUser" => 0,
        #      "allowPrivilegeEscalation" => false,
        #      "readOnlyRootFilesystem" => true
        #    },
        #    "volumeMounts" => [
        #      {
        #        "mountPath" => "/home/app",
        #        "name" => "scratch-dir"
        #      }
        #    ]
        #  }
        #],
        "containers" => [
          {
            #"terminationGracePeriodSeconds" => 5,
            #"ttlSecondsAfterFinished" => 1,
            "securityContext" => {
              "privileged" => true #TODO: figure out un-privd case, use kaniko???
            },
            "name" => clean_name,
            "image" => run_image,
            "imagePullPolicy" => "IfNotPresent",
            "workingDir" => job.parameters[:working_directory] || "/home/app/current", #TODO: local executor support
            "args" => sleep_cmd_args,
            "volumeMounts" => [
              {
                "mountPath" => "/var/run/docker.sock",
                "name" => "dood"
              },
              {
                "mountPath" => build_manifest_dir,
                "name" => "fd-config-volume"
              },
              {
                "mountPath" => "/home/app",
                "name" => "scratch-dir"
              },
              {
                "mountPath" => "/var/tmp/artifacts",
                "name" => "build-artifacts"
              },
              {
                "mountPath" => "/home/app/.ssh",
                "name" => "ssh-key"
              },
            ],
            "env" => job.parameters[:environment].collect { |k,v| {"name" => k, "value" => v } }
          }
        ],
        "volumes" => [
          {
            "name" => "dood",
            "hostPath" => {
              "path" => "/var/run/docker.sock"
            }
          },
          {
            "name" => "fd-config-volume",
            "configMap" => {
              "name" => "fd-#{clean_name}-#{current_revision}"
            }
          },
          {
            "name" => "git-repo",
            #TODO: bundle cache bits!! "emptyDir" => {} ????
            "hostPath" => {
              "path" => "/var/tmp/polly-safe/git/#{current_app}"
            }
          },
          {
            "name" => "scratch-dir",
            "hostPath" => {
              "path" => "/var/tmp/polly-safe/scratch/#{current_app}"
            }
          },
          {
            "name" => "build-artifacts",
            "hostPath" => {
              "path" => "/var/tmp/polly-safe/artifacts/#{current_app}"
            }
          },
          {
            "name" => "ssh-key",
            "hostPath" => {
              "path" => "#{ENV['HOME']}/.ssh"
            }
          }
        ]
      }

      unless @init
        container_spec.delete("initContainers")
      end

      configmap_manifest = {
        "apiVersion" => "v1",
        "kind" => "ConfigMap",
        "metadata" => {
          "name" => "fd-#{clean_name}-#{current_revision}"
        },
        "data" => {
          "run.sh" => job.parameters[:command]
        }
      }

      #TODO
      #puts YAML.dump(configmap_manifest) if @debug

      kubectl_apply = ["kubectl", "apply", "-f", "-"]
      apply_configmap_options = {:stdin_data => configmap_manifest.to_yaml}
      execute_simple(:silentx, kubectl_apply, apply_configmap_options)

      execute_simple(:silent, ["kubectl", "delete", "deployment/#{clean_name}", "--grace-period=1"], {})
      execute_simple(:silent, ["kubectl", "wait", "--for=delete", "deployment/#{clean_name}"], {})

      deployment_spec["spec"]["template"]["spec"] = container_spec

      apply_deployment_options = {:stdin_data => deployment_spec.to_yaml}
      execute_simple(:silentx, kubectl_apply, apply_deployment_options)

      execute_simple(:silent, ["kubectl", "wait", "--for=condition=available", "deployment/#{clean_name}"], {})

      find_all_pods = "kubectl get pods -l name=#{clean_name} -o name | cut -d/ -f2"
      a = IO.popen(find_all_pods).read.strip
      wait_child
      all_pods = a.split("\n")

      pod_index = 0
      ci_run_cmd = [
                     "kubectl", "exec",
                     all_pods[pod_index],
                     "--"
                   ]

      if executor_hints[:detach]
        ci_run_cmd += sleep_cmd_args
      else
        ci_run_cmd += run_cmd_args
      end

      #unless @keep_completed
      #  ci_run_cmd += ["--rm", "true"]
      #end
      #if executor_hints[:detach]
      #  ci_run_cmd += ["--attach", "false"]
      #else
      #  ci_run_cmd += ["--attach", "true"]
      #end

      if @debug
        puts ci_run_cmd.inspect
      end

      @runners << [job.run_name, clean_name, execute_simple(:async, ci_run_cmd, {})]
      @running_jobs[job.run_name] = job

      job
    end

    def wait_for_jobs_to_finish
      @iteration += 1

      io_this_loop = []

      jobs_to_mark_as_completed = []

      # decant runners into file descriptors for stdout/stderr
      process_fds = @runners.collect { |job_run_name, pod_name, cmd_io| [cmd_io[1], cmd_io[2]] }.flatten.compact

      # wait for changes or errors on all stdout/stderr descriptors
      _r, _w, _e = IO.select(process_fds, nil, process_fds, 1.0)

      @all_exited = true

      jobs_to_detach = []

      jobs_to_keep_completed = []

      @runners.each do |job_run_name, pod_name, cmd_io|
        next if cmd_io.empty?

        this_job = @running_jobs[job_run_name]

        process_waiter = cmd_io[3]

        handle_halted_job = false

        if process_waiter.alive?
          @all_exited = false

          chunk = 65432
          begin
            stdout = cmd_io[1].read_nonblock(chunk)
          rescue IO::EAGAINWaitReadable, Errno::EIO, Errno::EAGAIN, Errno::EINTR => err
            _r, _w, _e = IO.select(process_fds, nil, process_fds, 1.0)
            sleep 0.1
          rescue EOFError => err
          end

          begin
            stderr = cmd_io[2].read_nonblock(chunk)
          rescue IO::EAGAINWaitReadable, Errno::EIO, Errno::EAGAIN, Errno::EINTR => err
            _r, _w, _e = IO.select(process_fds, nil, process_fds, 1.0)
            sleep 0.1
          rescue EOFError => err
          end

          process_waiter.join(0.1)

          io_this_loop << [this_job, stdout, stderr]
        else
          if this_job
            proc_wait_value = process_waiter.value
            aok = proc_wait_value.success?
            jobs_to_mark_as_completed << this_job
            if !aok
              this_job.fail!

              if @short_circuit
                @exiting = true
              end

              if @detach_failed
                jobs_to_detach << this_job
              end
            end

            if @keep_completed
              jobs_to_keep_completed << this_job
            end

            @running_jobs.delete(job_run_name)

            chunk = 65432
            stdout = ""
            begin
              output = cmd_io[1].read_nonblock(chunk)
              stdout += output
            rescue IO::EAGAINWaitReadable, Errno::EIO, Errno::EAGAIN, Errno::EINTR => err
              _r, _w, _e = IO.select(process_fds, nil, process_fds, 1.0)
              sleep 0.1
            rescue EOFError => err
            end

            stderr = ""
            begin
              output = cmd_io[2].read_nonblock(chunk)
              stderr += output
            rescue IO::EAGAINWaitReadable, Errno::EIO, Errno::EAGAIN, Errno::EINTR => err
              _r, _w, _e = IO.select(process_fds, nil, process_fds, 1.0)
              sleep 0.1
            rescue EOFError => err
            end

            exit_proc = cmd_io[4]
            exit_proc.call(stdout, stderr, proc_wait_value, false)

            io_this_loop << [this_job, stdout, stderr]
          end
        end
      end

      jobs_to_detach.each do |failed_job|
        #failed_job.parameters[:executor_hints][:detach] = true
        #start_job!(failed_job)
      end

      jobs_to_mark_as_completed.each { |job_thang|
        #unless job_thang.parameters[:executor_hints][:detach]
          @runners.each { |job_namish, pod_name, cmd_io|
            if job_thang.run_name == job_namish
        #  #if jobs_to_mark_as_completed.include?(job_namish)
              unless jobs_to_keep_completed.include?(job_thang) || jobs_to_detach.include?(job_thang)
                #puts [jobs_to_mark_as_completed, jobs_to_detach, job_namish, pod_name].inspect
                execute_simple(:silent, ["kubectl", "delete", "deployment/#{pod_name}"], {})
              end
            end
          }
        #end
      }

      return jobs_to_mark_as_completed, io_this_loop
    end

    def running?
      if @exiting
        $stderr.write($/)
        $stderr.write("caught SIGINT, shutting down, please wait...")

        #TODO: handle better --wait-for flags
        unless (@keep_completed || @detach_failed)
          @runners.collect { |job_run_name, pod_name, cmd_io| execute_simple(:silent, ["kubectl", "delete", "deployment/#{pod_name}"], {}) }
        end

        return false if @all_exited
      else
        return true
      end
    end

    def wait_for_cleanup
      $stderr.write("cleaning up, please wait...")

      all_ok = @runners.all? { |job_run_name, pod_name, cmd_io| cmd_io.empty? || (!cmd_io[3].alive? && cmd_io[3].value.success?) }

      unless (@keep_completed || @detach_failed)
        $stderr.write("deleting deployment...")
        @runners.collect { |job_run_name, pod_name, cmd_io| execute_simple(:silent, ["kubectl", "delete", "deployment/#{pod_name}"], {}) }
      end

      while (!@detach_failed && !@keep_completed && @runners.any? { |job_run_name, pod_name, cmd_io|
        $stderr.write(".")
        #TODO:
        #execute_simple(:silent, ["kubectl", "get", "pod/#{pod_name}"], {})
        #execute_simple(:silent, ["kubectl", "wait", "pod/#{pod_name}"], {})
        execute_simple(:silent, ["kubectl", "wait", "--for=delete", "deployment/#{pod_name}"], {})
      }) do
        $stderr.write(".")
        sleep 0.1
      end

      wait_child unless (@keep_completed || @detach_failed)

      trap 'INT', 'DEFAULT'

      $stderr.write($/)
      
      all_ok
    end

    def execute_simple(mode, cmd, options)
      exit_proc = lambda { |stdout, stderr, wait_thr_value, exit_or_not, silent=false|
        if !wait_thr_value.success?
          if exit_or_not
            #TODO: integrate Observe here for fatal halt error log
            puts caller
            puts stdout
            puts stderr
            Kernel.exit(1)
          end
        end

        return stdout, stderr, wait_thr_value.success?
      }

      case mode
        when :silent
          o, e, s = Open3.capture3(*cmd, options)
          return s.success?

        when :silentx
          o, e, s = Open3.capture3(*cmd, options)
          s.success?
          return exit_proc.call(o, e, s, true, true)

        #TODO: rename to critical_or_fail
        when :critical_or_fail
          o, e, s = Open3.capture3(*cmd, options)
          return exit_proc.call(o, e, s, true)

        when :output
          o, e, s = Open3.capture3(*cmd, options)
          return exit_proc.call(o, e, s, false)

        when :async
          stdin, stdout, stderr, wait_thr = Open3.popen3(*cmd, options)
          return [stdin, stdout, stderr, wait_thr, exit_proc]

      end
    end

    def wait_child
      Process.wait rescue Errno::ECHILD
    end

    def execute_procfile(working_directory, procfile = "Procfile")
      obv = ::Polly::Observe.new

      time_started = Time.now
      chunk = 65432
      exiting = false
      exit_grace_counter = 0
      term_threshold = 3
      kill_threshold = term_threshold + 5 #NOTE: timing controls exit status
      total_kill_count = kill_threshold + 7
      select_timeout = 10.0
      needs_winsize_update = false
      trapped = false
      self_reader, self_write = IO.pipe

      trap 'INT' do
        self_write.write_nonblock("\0")

        if exiting && exit_grace_counter < kill_threshold
          exit_grace_counter += 1
        end

        exiting = true
        trapped = true
        select_timeout = 1.0
      end

      trap 'WINCH' do
        needs_winsize_update = true
      end

      Dir.chdir(working_directory || Dir.mktmpdir)

      pipeline_commands = File.readlines(procfile).collect { |line|
        process_name, process_cmd = line.split(":", 2)
        process_name.strip!
        process_cmd.strip!
        process_options = {}

        process_stdin, process_stdout, process_stderr, process_waiter = execute_simple(:async, process_cmd, process_options)
        {
          :process_name => process_name,
          :process_cmd => process_cmd,
          :process_env => {},
          :process_options => process_options,
          :process_stdin => process_stdin,
          :process_stdout => process_stdout,
          :process_stderr => process_stderr,
          :process_waiter => process_waiter
        }
      }

      obv.register_channels(pipeline_commands.collect { |pipeline_command| pipeline_command[:process_name] })

      process_stdouts = pipeline_commands.collect { |pipeline_command| pipeline_command[:process_stdout] }
      process_stdouts += [self_reader]

      process_stderrs = pipeline_commands.collect { |pipeline_command| pipeline_command[:process_stderr] }
      process_stderrs += [self_reader]

      detected_exited = []

      until pipeline_commands.all? { |pipeline_command| !pipeline_command[:process_waiter].alive? }
        obv.flush($stdout, $stderr)

        if exiting
          exit_grace_counter += 1

          $stdout.write(" ... trying to exit gracefully, please wait #{exit_grace_counter} / #{total_kill_count}")
          $stdout.write($/)

          pipeline_commands.each do |pipeline_command|
            process_name = pipeline_command[:process_name]
            pid = pipeline_command[:process_waiter][:pid]

            unless detected_exited.include?(pid)
              begin
                resolution = :SIGINT

                if exit_grace_counter > kill_threshold
                  resolution = :SIGKILL
                  Process.kill('KILL', pid)
                end

                if exit_grace_counter > term_threshold
                  resolution = :SIGTERM
                  Process.kill('TERM', pid)
                end

                Process.kill('INT', pid)
              rescue Errno::EPERM, Errno::ECHILD, Errno::ESRCH => e
                detected_exited << pid
              end
            end
          end
        end

        ready_for_reading, _w, _e = IO.select(process_stdouts + process_stderrs, nil, nil, select_timeout)

        self_reader.read_nonblock(chunk) rescue nil

        ready_for_reading && pipeline_commands.each { |pipeline_command|
          process_name = pipeline_command[:process_name]
          stdout = pipeline_command[:process_stdout]
          stderr = pipeline_command[:process_stderr]

          begin
            if ready_for_reading.include?(stdout)
              stdout_chunk = stdout.read_nonblock(chunk)
              obv.stack_stdout(process_name, stdout_chunk)
            end
          rescue EOFError => e
            process_stdouts.delete(stdout)
          rescue IO::EAGAINWaitReadable, Errno::EIO, Errno::EAGAIN, Errno::EINTR=> e
            nil
          end

          begin
            if ready_for_reading.include?(stderr)
              stderr_chunk = stderr.read_nonblock(chunk)
              obv.stack_stderr(process_name, stderr_chunk)
            end
          rescue EOFError => e
            process_stderrs.delete(stderr)
          rescue IO::EAGAINWaitReadable, Errno::EIO, Errno::EAGAIN, Errno::EINTR=> e
            nil
          end
        }

        pipeline_commands.each { |pipeline_command|
          pid = pipeline_command[:process_waiter][:pid]
          process_name = pipeline_command[:process_name]
          process_waiter = pipeline_command[:process_waiter]

          unless process_waiter.alive? || detected_exited.include?(pid)
            detected_exited << pid
            process_result = process_waiter.value

            $stdout.write("#{process_name} exited... #{process_result.success?}")
            $stdout.write($/)
          end
        }
      end

      trap 'INT', 'DEFAULT'
      trap 'WINCH', 'DEFAULT'

      pipeline_commands.each { |pipeline_command|
        process_name = pipeline_command[:process_name]
        process_waiter = pipeline_command[:process_waiter]
        process_result = process_waiter.value
      }

      # ensure nothing is left around
      wait_child

      obv.flush($stdout, $stderr, true)

      $stdout.write(" ... exiting")
      $stdout.write($/)
    end

    def polly_pod(label = "name=#{POLLY}-git")
      @polly_pods ||= {}
      @polly_pods[label] ||= begin
        cmd = "kubectl get pods -l #{label} -o name | cut -d/ -f2"
        a = IO.popen(cmd).read.strip
        wait_child
        a
      end
    end

    def in_polly?
      current_app == POLLY
    end

    def pump_io
    end
  end
end
