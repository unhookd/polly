#

module Polly
  class Build

    def self.build_image_to_tag(app, build_image, version)
      app + ":" + build_image.stage + "-" + version
    end

    def generated_dockerfile_fd(generated_dockerfile)
      fd = Tempfile.new("dockerfile")
      fd.write(generated_dockerfile)
      fd.rewind
      fd
    end

    def self.buildkit_external(exe, app, build_image, version, generated_dockerfile, force_no_cache)
      tag = build_image_to_tag(app, build_image, version)

      build_dockerfile = [
        {"DOCKER_BUILDKIT" => "1", "SSH_AUTH_SOCK" => ENV["SSH_AUTH_SOCK"]},
        "docker", "build", "--progress=plain", "--ssh", "default",
        force_no_cache ? "--no-cache" : nil,
        "--target", build_image.stage, 
        "-t", tag, 
        "-f", "-",
        ".",
        {:in => generated_dockerfile_fd(generated_dockerfile)}
      ].compact

      #o,e,s = exe.execute_simple(:output, build_dockerfile, io_options)
      #puts [o, e]
      exe.systemx(*build_dockerfile)
    
      puts "Built and tagged: #{tag} OK"
    end

    def self.buildkit_internal(exe, app, build_image, version, generated_dockerfile, force_no_cache)
      tag = build_image_to_tag(app, build_image, version)
      stage = app + "-" + build_image.stage

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

      origin = "/polly-safe/git/#{app}"

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
          mountPath: /polly-safe
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
        #- type=registry,ref=polly-registry:443/#{app}
        - --import-cache
        - type=local,src=/polly-safe/buildkit,mode=max
        - --frontend
        - dockerfile.v0
        - --local
        - context=/home/app/#{app}
        - --local
        - dockerfile=/tmp/#{app}
        #- --export-cache
        #- type=inline
        #- --export-cache
        #- type=registry,ref=polly-registry:443/#{app}
        - --export-cache
        - type=local,dest=/polly-safe/buildkit,mode=max
        - --output
        - type=tar,dest=/polly-safe/buildkit/#{tag}.tar
        #- --output
        #- type=image,name=#{app}/#{tag},push=true
        ##- --output
        ##- type=image,name=polly-registry:443/#{tag},push=true
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
        #- mountPath: /home/user/.docker/config.json
        #  subPath: config.json
        #  name: docker-config
        - mountPath: /tmp/#{app}/Dockerfile
          subPath: Dockerfile
          name: polly-dockerfile-#{app}
        - name: workspace
          mountPath: /home/app/#{app}
          readOnly: true
        - name: polly-mount
          mountPath: /polly-safe
          #readOnly: true
        - mountPath: /etc/ssl/certs
          name: ca-certificates
          readOnly: true
        - mountPath: /etc/ssl/cert.pem
          subPath: ca-certificates.crt
          name: ca-certificates
      volumes:
      #- name: docker-config
      #  secret:
      #    secretName: docker-config
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
  end
end
