#

module Polly
  class Config
    def self.rc
      @rc ||= begin
        YAML.load(File.read(File.expand_path("~/.pollyrc")))
      rescue Errno::ENOENT
        {}
      end
    end

    def self.allowed_contexts
      rc["allowed_contexts"] || ["polly-ci", "kubernetes-admin@kubernetes"]
    end

    def self.image_repo
      rc["image_repo"] || "polly-registry:443"
    end
  end
end
