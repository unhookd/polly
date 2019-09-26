require "spec_helper"

describe Polly::Execute do
  let(:exe) { described_class.new }

  before do
  end

  context "performing locally" do
    it "has a simple method that exits on failure" do
      expect(Kernel).to receive(:system).with('true').and_return(true)
      exe.systemx('true')

      expect(Kernel).to receive(:system).with('false').and_return(false)
      expect(Kernel).to receive(:exit).with(1).and_return(true)
      exe.systemx('false')
    end
  end

  context "performing on a kubernetes cluster backend" do
    before do
    end

    it "has an initial spec" do
      expect(true).to eq(true)
    end
  end
end
