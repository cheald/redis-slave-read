require "spec_helper"

describe Redis::SlaveRead::Interface::Hiredis do
  let(:master) { Redis.new }
  let(:slaves) { [Redis.new, Redis.new] }

  subject { described_class.new master: master, slaves: slaves }

  it "should distribute reads between all available nodes" do
    expect(master).to receive(:get).once
    expect(slaves[0]).to receive(:get).once
    expect(slaves[1]).to receive(:get).once

    3.times { subject.get "foo" }
  end

  it "should always send non-reads to the master" do
    expect(master).to receive(:set).exactly(3).times

    3.times { subject.set "foo", "bar" }
  end

  context "when read_master is false" do
    subject { described_class.new master: master, slaves: slaves, read_master: false }

    it "should distribute reads between all available slaves" do
      expect(master).to receive(:get).never
      expect(slaves[1]).to receive(:get).twice
      expect(slaves[0]).to receive(:get).twice

      4.times { subject.get "foo" }
    end
  end

  context "when in a multi block" do
    it "sends all commands to the master" do
      expect(master).to receive(:get).twice

      subject.multi do
        2.times { subject.get "foo" }
      end
    end

    it "returns replies to all commands in multi block" do
      results = subject.multi do
        subject.set 'foo', 'bar'
        subject.get 'foo'
      end
      expect(results).to eq(['OK', 'bar'])
    end
  end

  context "when in a pipelined block" do
    it "sends all commands to the master" do
      expect(master).to receive(:get).twice

      subject.pipelined do
        2.times { subject.get "foo" }
      end
    end

    it "returns replies to all commands in pipelined block" do
      results = subject.pipelined do
        2.times { subject.set 'foo', 'bar' }
      end
      expect(results).to eq(['OK', 'OK'])
    end
  end

  context "commands that distribute to all nodes" do
    it "should distribute to each node" do
      expect(master).to receive(:select).once
      slaves.each {|slave| expect(slave).to receive(:select).once }
      subject.send(:select)
    end

    it "should set the DB on each node" do
      subject.select 4
      expect(master.client.db).to eq 4
      expect(slaves[0].client.db).to eq 4
      expect(slaves[1].client.db).to eq 4
    end

    it "should connect and disconnect each client" do
      subject.connect
      expect(!!master.client.connected?).to be_truthy
      expect(!!slaves[0].client.connected?).to be_truthy
      expect(!!slaves[1].client.connected?).to be_truthy

      subject.disconnect
      expect(!!master.client.connected?).to be_falsey
      expect(!!slaves[0].client.connected?).to be_falsey
      expect(!!slaves[1].client.connected?).to be_falsey
    end
  end
end
