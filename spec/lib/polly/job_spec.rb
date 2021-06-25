require "spec_helper"

describe Polly::Job do
  let(:valid_run_name) { "tests" }
  let(:valid_parameters) {
    {
      :environment => {
        "FOO" => "bar"
      },

      :command => "env",

      :working_directory => "/home/app/current",

      :executor_hints => {
        :docker => {
          :image => "polly:latest"
        }
      }
    }
  }

  let(:job) { described_class.new(valid_run_name, valid_parameters) }
  let(:invalid_job) { described_class.new }

  context "direct job creation" do
    it "allows jobs to be directly created" do
      expect(job.run_name).to eq(valid_run_name)
      expect(job.valid?).to eq(true)

      expect(invalid_job.valid?).to eq(false)
    end
  end
end
