require "spec_helper"

describe Polly::Observe do
  context "channels" do
    it "allows more than one channel of reporting" do
      obv = ::Polly::Observe.new
      obv.register_channels(["a", "b"])

      obv.report_stdout("a", "stdout from a")
      obv.report_stderr("a", "stderr from a")

      obv.report_stdout("b", "stdout from b")
      obv.report_stderr("b", "stderr from b")

      stdout_io = StringIO.new
      stderr_io = StringIO.new

      obv.flush(stdout_io, stderr_io)

      expect(stdout_io.string).to include("stdout from a", "stdout from b")
      expect(stderr_io.string).to include("stderr from a", "stderr from b")
    end
  end

  context "output without newlines" do
    it "allows output to be buffered upto a certain amount even without newlines" do
      obv = ::Polly::Observe.new
      obv.register_channels(["a"])

      obv.report_io("a", "stdout from a no newlines" * 128, "stderr from a no newlines" * 128)

      stdout_io = StringIO.new
      stderr_io = StringIO.new

      obv.flush(stdout_io, stderr_io)

      #TODO: use eq() test for better specs
      expect(stdout_io.string).to include("stdout from a")
      expect(stderr_io.string).to include("stderr from a")
    end
  end
end
