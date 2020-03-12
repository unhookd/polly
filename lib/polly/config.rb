#

module Polly
  class Config
    def self.rc
      YAML.load(File.read(File.expand_path("~/.pollyrc")))
    end

    def self.allowed_contexts
      rc["allowed_contexts"] || ["kubernetes-admin@kubernetes"]
    end

    def self.image_repo
      rc["image_repo"] || "polly-app:443"
    end
  end
end
