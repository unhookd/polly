#

module Polly
  class Build
    def self.build_image_to_tag(app, build_image_stage, version)
      app + ":" + build_image_stage + "-" + version
    end

    def self.generated_string_fd(generated_dockerfile)
      fd = Tempfile.new("polly-string-fd")
      fd.write(generated_dockerfile)
      fd.rewind
      fd
    end

    def self.buildkit_workstation_to_controller(exe, app, build_image_stage, version, force_no_cache)
      #TODO: figure out refactor for stdin/generated container image specification
      #file = Tempfile.new('Dockerfile', Dir.pwd)
      #file.write(generated_dockerfile)
      #file.rewind
      #puts file.path
      tag = build_image_to_tag(app, build_image_stage, version)
      buildctl_local_cmd = [
        {"SSH_AUTH_SOCK" => ENV["SSH_AUTH_SOCK"]},
        "buildctl",
        "--addr", "kube-pod://polly-buildkitd-0",
        "build",
        "--progress=plain",
        "--ssh", "default", #"default=#{Dir.home}/.ssh/id_rsa",
        "--frontend", "dockerfile.v0",
        "--local", "context=.", "--local", "dockerfile=.",
        "--output", "type=image,name=polly-registry:23443/polly-registry/#{tag},push=true"
      ]
      exe.systemx(*buildctl_local_cmd) || fail("unable to build")
      puts "Built and tagged: #{tag} OK"
    end

    def self.buildkit_external(exe, app, build_image_stage, version, generated_dockerfile, force_no_cache)
      raise
      ##file = Tempfile.new('Dockerfile', Dir.pwd)
      ##file.write(generated_dockerfile)
      ##file.rewind
      ##puts file.path
      #tag = build_image_to_tag(app, build_image_stage, version)
      #buildctl_local_cmd = [
      #  {"SSH_AUTH_SOCK" => ENV["SSH_AUTH_SOCK"]},
      #  "buildctl",
      #  "--addr", "kube-pod://polly-buildkitd-0",
      #  "build",
      #  "--ssh", "default", #"default=#{Dir.home}/.ssh/id_rsa",
      #  "--frontend", "dockerfile.v0",
      #  "--local", "context=.", "--local", "dockerfile=.", #"--opt", "filename=#{File.basename(file.path)}",
      #  "--output", "type=image,name=polly-registry:443/polly-registry/#{tag},push=true" #,
      #  #{:in => generated_string_fd(generated_dockerfile)}
      #]
      #puts buildctl_local_cmd.inspect
      #exe.systemx(*buildctl_local_cmd)
      #puts "Built and tagged: #{tag} OK"
    end

    def self.buildkit_internal(exe, app, build_image_stage, version, generated_dockerfile, force_no_cache)
      tag = build_image_to_tag(app, build_image_stage.stage, version)
      stage = app + "-" + build_image_stage.stage

      polly_dockerfile_config = []
      polly_dockerfile_config << <<-HEREDOC
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: polly-dockerfile-#{app}
binaryData:
  Dockerfile: #{Base64.strict_encode64(generated_dockerfile)}
...
HEREDOC

      apply_job = ["kubectl", "apply", "-f", "-"]
      apply_options = {:stdin_data => polly_dockerfile_config.join}
      o,e,s = exe.execute_simple(:output, apply_job, apply_options)
      puts [o, e]

      origin = "/polly/safe/git/#{app}"

      build_jobs = ""

      build_jobs << <<-HEREDOC
---
apiVersion: batch/v1
kind: Job
metadata:
  name: buildkit-#{stage}
  labels:
    stack: polly
spec:
  backoffLimit: 0
  template:
    metadata:
      annotations:
        container.apparmor.security.beta.kubernetes.io/buildkit: unconfined
        container.seccomp.security.alpha.kubernetes.io/buildkit: unconfined
    spec:
      restartPolicy: Never

      initContainers:
      #- name: amazon-ecr-credential-helper-build
      #  image: golang:1.9.1-alpine3.6
      #  command:
      #  - sh
      #  - -c
      #  - "test -e /polly-safe/bin/docker-credential-ecr-login || (apk --no-cache add git && go get -u github.com/awslabs/amazon-ecr-credential-helper/ecr-login/cli/docker-credential-ecr-login && mkdir /polly-safe/bin && mv /go/bin/docker-credential-ecr-login /polly-safe/bin)"
      #  securityContext:
      #    runAsUser: 0
      #    runAsGroup: 0
      #  volumeMounts:
      #  - name: polly-mount
      #    mountPath: /polly-safe
      - name: git-clone
        image: alpine/git:latest
        command:
        - git
        - clone
        - -b
        - #{exe.current_branch}
        - #{origin}
        - .
        workingDir: /home/app/#{app}
        securityContext:
          runAsUser: 1000
          runAsGroup: 1000
        volumeMounts:
        - name: workspace
          mountPath: /home/app/#{app}
        - name: polly-mount
          mountPath: /polly/safe
        - mountPath: /etc/ssl/certs
          name: ca-certificates
          readOnly: true
      containers:
      - name: buildkit
        workingDir: /home/app/#{app}
        image: moby/buildkit:master-rootless
        #image: moby/buildkit:v0.6.4-rootless
        env:
        - name: BUILDKITD_FLAGS
          value: --oci-worker-no-process-sandbox
        command:
        - buildctl-daemonless.sh
        args:
        - build
        #- --import-cache
        #- type=registry,ref=polly-registry:23443/#{app}
        - --import-cache
        - type=local,src=/polly/safe/buildkit,mode=max
        - --frontend
        - dockerfile.v0
        - --local
        - context=/home/app/#{app}
        - --local
        - dockerfile=/tmp/#{app}
        #- --export-cache
        #- type=inline
        #- --export-cache
        #- type=registry,ref=polly-registry:23443/#{app}
        - --export-cache
        - type=local,dest=/polly/safe/buildkit,mode=max
        #- --output
        #- type=tar,dest=/polly-safe/buildkit/#{tag}.tar
        #- --output
        #- type=image,name=#{app}/#{tag},push=true
        ##- --output
        ##- type=image,name=polly-registry:23443/#{tag},push=true
        resources:
          requests:
            memory: 5000Mi
            cpu: 500m
          limits:
            memory: 5000Mi
            cpu: 4000m
        securityContext:
          runAsUser: 1000
          runAsGroup: 1000
        volumeMounts:
        - mountPath: /tmp/#{app}/Dockerfile
          subPath: Dockerfile
          name: polly-dockerfile-#{app}
        - name: workspace
          mountPath: /home/app/#{app}
          readOnly: true
        - name: polly-mount
          mountPath: /polly/safe
          #readOnly: true
        - mountPath: /etc/ssl/certs
          name: ca-certificates
          readOnly: true
        - mountPath: /etc/ssl/cert.pem
          subPath: ca-certificates.crt
          name: ca-certificates
      volumes:
      - name: polly-dockerfile-#{app}
        configMap:
          name: polly-dockerfile-#{app}
      - name: ca-certificates
        secret:
          secretName: ca-certificates
      - name: polly-mount
        persistentVolumeClaim:
          claimName: polly-mount
      - name: workspace
        emptyDir: {}
...
HEREDOC

      build_pod_label = "job-name=buildkit-#{stage}"

      delete_job = ["kubectl", "delete", "-f", "-"]
      io_options = {:stdin_data => build_jobs}
      o,e,s = exe.execute_simple(:output, delete_job, io_options)

      wait_build_pod_deleted = ["kubectl", "wait", "--for=delete", "pod", "-l", build_pod_label]
      o,e,s = exe.execute_simple(:output, wait_build_pod_deleted, {})

      build_job_apply = ["kubectl", "apply", "-f", "-"]
      io_options = {:stdin_data => build_jobs}
      o,e,s = exe.execute_simple(:output, build_job_apply, io_options)
      puts [o, e]

      wait_build_job = ["kubectl", "get", "pods", "-l", build_pod_label, "-o", "jsonpath={..status.conditions[?(@.type=='Ready')].status}"]
      o,e,s = "False"

      while o != "True" && exe.running?
        sleep 1
        cmd = ["kubectl", "logs", "-l", build_pod_label, "-c", "git-clone"]
        puts cmd
        o,e,s = exe.execute_simple(:output, ["kubectl", "logs", "-l", build_pod_label, "-c", "git-clone"], {})
        puts o,e
        if s
          puts [o, e]
          o,e,s = exe.execute_simple(:output, wait_build_job, {})
        end
      end

      build_pod = exe.polly_pod(build_pod_label)
      exec(*["kubectl", "logs", build_pod, "-f"].compact)
    end

    def self.build_cloudinit_yaml(exe, vertical_lookup, client_key_pub, server_key, server_key_pub)
      prewrites = vertical_lookup["prewrites"]

      users = [{
        'name' => 'app',
        'shell' => '/bin/bash',
        'groups' => 'sudo',
        'sudo' => 'ALL=(ALL) NOPASSWD:ALL',
        'ssh_authorized_keys' => [client_key_pub]
      }]

      write_files = []

      prewrites.each { |glob|
        Dir.glob(glob).find_all { |f| File.file?(f) }.each { |f|
          write_files << {
            'content' => File.read(f),
            'path' => File.join('/var/tmp', exe.current_app, f),
            'permissions' => File.stat(f).mode.to_s(8)
          }
        }
      }

      write_files << {
        'content' => server_key.strip + "\n",
        'path' => '/etc/ssh/custom_ssh_host_rsa_key',
        'permissions' => '0600'
      }

      write_files << {
        'content' => server_key_pub.strip + " root@threep" + "\n",
        'path' => '/etc/ssh/custom_ssh_host_rsa_key.pub',
        'permissions' => '0600'
      }

      write_files << {
        'content' => "HostKey /etc/ssh/custom_ssh_host_rsa_key" + "\n",
        'path' => '/etc/ssh/sshd_config.d/custom.conf',
        'permissions' => '0644'
      }
#mirrors:
#  "docker.io":
#    endpoint:
#      - "https://polly-registry:443"
#  "polly-registry":
#    endpoint:
#      - "https://polly-registry:23443"
#configs:
#  "polly-registry:23443":
#    tls:
#      #cert_file: # path to the cert file used in the registry
#      #key_file:  # path to the key file used in the registry
#      ca_file: /home/app/workspace/polly/ca  # path to the ca file used in the registry
      polly_registry_k3s_config = {
        "mirrors" => {
          #"docker.io" => {
          #  "endpoint" => [
          #    "https://polly-registry:443"
          #  ]
          #},
          "polly-registry" => {
            "endpoint" => [
              "https://polly-registry:23443"
            ]
          }
        },
        "configs" => {
          "polly-registry:24443" => {
            "tls" => {
              "ca_file" => "/home/app/workspace/polly/ca"
            }
          }
        }
      }

      write_files << {
        'content' => YAML.dump(polly_registry_k3s_config),
        'path' => '/etc/rancher/k3s/registries.yaml',
        'permissions' => '0644'
      }



      write_files << {
        'content' => "127.0.1.1 $hostname $hostname\n127.0.0.1 localhost\n" + vertical_lookup["host-aliases"].collect { |ha| ha["hostnames"].collect { |hn| ha["ip"] + " " + hn }.join("\n") }.join("\n") + "" + "\n",
        'path' => '/etc/cloud/templates/hosts.debian.tmpl',
        'permissions' => '0644'
      }

      {
        'users' => users,
        'write_files' => write_files,
        'manage_etc_hosts' => true
      }.to_yaml
    end
  end
end
