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
        @output.rewind
        @output.read
      end

      #def circleci_output
      #  @circleci_output ||= StringIO.new # $stdout
      #end

      def read_circleci_output
        #@circleci_output.rewind
        #@circleci_output.read
        File.read("spec/fixtures/dot-circleci/config.yml")
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
        comment "syntax=docker/dockerfile-upstream:master-experimental"

        yield

        comment "Generated #{Time.now}"

        @image_name
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
