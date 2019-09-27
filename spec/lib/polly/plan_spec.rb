require "spec_helper"

describe Polly::Plan do
  let(:valid_revision) { "abc123" }
  let(:valid_concurrency_option) { { "concurrency" => 640 } }

  context "direct planning" do
    it "can coordinate two interdependent jobs" do
      plan = described_class.new(valid_revision)

      job_a = Polly::Job.new("a")
      job_b = Polly::Job.new("b")

      plan.add_job(job_a)
      plan.add_job(job_b)
      plan.depends(job_b.run_name, job_a.run_name)
      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_a])
      plan.complete_job!(job_a)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_b])
      plan.complete_job!(job_b)

      expect(plan.has_unfinished_jobs?).to eq(false)
    end

    it "can handle multiple levels of concurrency" do
      plan = described_class.new(valid_revision, nil, {"dry-run" => true, "concurrency" => 1, "skip" => "a"})

      job_a = Polly::Job.new("a")
      job_b = Polly::Job.new("b")
      job_c = Polly::Job.new("c")
      job_d = Polly::Job.new("d")

      plan.add_job(job_a)
      plan.add_job(job_b)
      plan.add_job(job_c)
      plan.add_job(job_d)
      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_b])
      plan.complete_job!(job_b)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_c])
      plan.complete_job!(job_c)

      expect(plan.has_unfinished_jobs?).to eq(true)

      plan = described_class.new(valid_revision, nil, {"dry-run" => true, "concurrency" => 3, "skip" => "a"})

      job_a = Polly::Job.new("a")
      job_b = Polly::Job.new("b")
      job_c = Polly::Job.new("c")
      job_d = Polly::Job.new("d")

      plan.add_job(job_a)
      plan.add_job(job_b)
      plan.add_job(job_c)
      plan.add_job(job_d)
      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_b, job_c, job_d])
      plan.complete_job!(job_b)
      plan.complete_job!(job_c)
      plan.complete_job!(job_d)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([])

      expect(plan.has_unfinished_jobs?).to eq(false)
    end

    it "can abort dead-end pipelines" do
      plan = described_class.new(valid_revision)

      job_a = Polly::Job.new("a")
      job_b = Polly::Job.new("b")
      job_c = Polly::Job.new("c")
      job_d = Polly::Job.new("d")
      job_e = Polly::Job.new("e")

      plan.add_job(job_a)
      plan.add_job(job_b)
      plan.add_job(job_c)
      plan.add_job(job_d)
      plan.add_job(job_e)

      plan.depends(job_b.run_name, job_a.run_name)
      plan.depends(job_c.run_name, job_a.run_name)
      plan.depends(job_d.run_name, job_a.run_name)
      plan.depends(job_e.run_name, job_d.run_name)

      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_a])
      job_a.fail!
      plan.complete_job!(job_a)

      expect(plan.has_unfinished_jobs?).to eq(false)
    end

    it "runs until only dead-end pipelines or all jobs are finished" do
      plan = described_class.new(valid_revision, nil, {"concurrency" => 2})

      job_a = Polly::Job.new("a")
      job_b = Polly::Job.new("b")
      job_c = Polly::Job.new("c")
      job_d = Polly::Job.new("d")
      job_e = Polly::Job.new("e")

      plan.add_job(job_a)
      plan.add_job(job_b)
      plan.add_job(job_c)
      plan.add_job(job_d)
      plan.add_job(job_e)

      plan.depends(job_b.run_name, job_a.run_name)
      plan.depends(job_c.run_name, job_a.run_name)
      plan.depends(job_e.run_name, job_d.run_name)

      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs.count).to eq(2)
      expect(ready_to_start_jobs).to eq([job_a, job_d])
      job_a.fail!
      plan.complete_job!(job_a)
      plan.complete_job!(job_d)

      expect(plan.has_unfinished_jobs?).to eq(true)
      
      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_e])
      plan.complete_job!(job_e)
      expect(plan.has_unfinished_jobs?).to eq(false)
    end

    it "allows jobs to be skipped" do
      plan = described_class.new(valid_revision, nil, {"concurrency" => 2, "skip" => "a:b"})

      job_a = Polly::Job.new("a")
      job_b = Polly::Job.new("b")
      job_c = Polly::Job.new("c")
      job_d = Polly::Job.new("d")

      plan.add_job(job_a)
      plan.add_job(job_b)
      plan.add_job(job_c)
      plan.add_job(job_d)

      plan.depends(job_b.run_name, job_a.run_name)
      plan.depends(job_c.run_name, job_b.run_name)

      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_c, job_d])
      plan.complete_job!(job_c)
      plan.complete_job!(job_d)

      expect(plan.has_unfinished_jobs?).to eq(false)
    end

    it "allows jobs to be specified as only run" do
      plan = described_class.new(valid_revision, nil, {"concurrency" => 2, "only" => "c:d"}) 

      job_a = Polly::Job.new("a")
      job_b = Polly::Job.new("b")
      job_c = Polly::Job.new("c")
      job_d = Polly::Job.new("d")

      plan.add_job(job_a)
      plan.add_job(job_b)
      plan.add_job(job_c)
      plan.add_job(job_d)

      plan.depends(job_b.run_name, job_a.run_name)
      plan.depends(job_c.run_name, job_b.run_name)

      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_c, job_d])
    end

    it "allows jobs to targeted but run deps upto targets" do
      plan = described_class.new(valid_revision, "f", {"concurrency" => 1})

      job_a = Polly::Job.new("a")
      job_b = Polly::Job.new("b")
      job_c = Polly::Job.new("c")
      job_d = Polly::Job.new("d")
      job_e = Polly::Job.new("e")
      job_f = Polly::Job.new("f")

      plan.add_job(job_a)
      plan.add_job(job_b)
      plan.add_job(job_c)
      plan.add_job(job_d)
      plan.add_job(job_e)
      plan.add_job(job_f)

      plan.depends(job_f.run_name, job_e.run_name)
      plan.depends(job_f.run_name, job_d.run_name)
      plan.depends(job_e.run_name, job_d.run_name)
      plan.depends(job_e.run_name, job_c.run_name)

      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_c])
      
      plan.complete_job!(job_c)

      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_d])

      plan.complete_job!(job_d)

      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_e])

      plan.complete_job!(job_e)

      expect(plan.has_unfinished_jobs?).to eq(true)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([job_f])

      plan.complete_job!(job_f)

      expect(plan.has_unfinished_jobs?).to eq(false)
    end
  end

  context "loading from circleci like yaml config" do
    it "constructs a plan with correct dependency tree based on provided yaml" do
      plan = described_class.new(valid_revision)

      plan.load_circleci

      expect(plan.has_unfinished_jobs?).to eq(true)

      expect(plan.all_jobs.count).to eq(1)

      ready_to_start_jobs = plan.jobs_ready_to_start
      expect(ready_to_start_jobs).to eq([plan.all_jobs["primary"]])

      plan.complete_job!(plan.all_jobs["primary"])

      expect(plan.has_unfinished_jobs?).to eq(false)
    end
  end

#  context "translating to circleci" do
#    it "can emit a circleci config file from a directly programmed plan" do
#      job_a = Job.new
#      job_b = Job.new
#      job_c = DockerBuildJob.new
#      job_d = BundleInstallJob.new
#      job_e = YarnAndWebpackJob.new
#
#      plan.add_job(job_a)
#      plan.add_job(job_b)
#
#      plan.depends(job_b, job_a)
#
#      emitted_yml = plan.circleci_yml
#
#      reconstructed_plan = Plan.new(emitted_yml)
#
#      plan == reconstructed_plan
#    end
#  end

  #it "new syntax" do
  #  plan = describe_class.new(conncurency, desired_targets, desired_skips, desired_onlys)

  #  # off-road'n
  #  # (desired_targets || default_all_targets) === safe, just don't do the whole tree
  #  #   skips === "--ignore-these-jobs="
  #  #   onlys === "--jump-to-these-steps="

  #  job_a = plan.new_job("a")
  #  job_b = plan.new_job("b")

  #  job_b << a
  #end
end
