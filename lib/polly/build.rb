#

module Polly
  class Build

    def self.build_image_to_tag(app, build_image, version)
      app + ":" + build_image.stage + "-" + version
    end

    def self.buildkit_external(exe, app, build_image, version, generated_dockerfile, force_no_cache)
    puts generated_dockerfile

      tag = build_image_to_tag(app, build_image, version)

      generated_dockerfile_fd = Tempfile.new("dockerfile")
      generated_dockerfile_fd.write(generated_dockerfile)
      generated_dockerfile_fd.rewind

      build_dockerfile = [
        {"DOCKER_BUILDKIT" => "1", "SSH_AUTH_SOCK" => ENV["SSH_AUTH_SOCK"]},
        "docker", "build", "--progress=plain", "--ssh", "default",
        force_no_cache ? "--no-cache" : nil,
        "--target", build_image.stage, 
        "-t", tag, 
        "-f", "-",
        ".",
        {:in => generated_dockerfile_fd}
      ].compact

      #o,e,s = exe.execute_simple(:output, build_dockerfile, io_options)
      #puts [o, e]
      exe.systemx(*build_dockerfile)
    
      puts "Built and tagged: #{tag} OK"
    end
  end
end
