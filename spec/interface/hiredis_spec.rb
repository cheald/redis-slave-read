require "spec_helper"

describe Redis::Distributor::Interface::Hiredis do
  let(:master) { Redis.new }
  let(:slaves) { [Redis.new, Redis.new] }

  subject { described_class.new master: master, slaves: slaves }

  it "should distribute reads between all available nodes" do
    master.should_receive(:get).once
    slaves[0].should_receive(:get).once
    slaves[1].should_receive(:get).once

    3.times { subject.get "foo" }
  end

  it "should always send non-reads to the master" do
    master.should_receive(:set).exactly(3).times

    3.times { subject.set "foo", "bar" }
  end

  context "when read_master is false" do
    subject { described_class.new master: master, slaves: slaves, read_master: false }

    it "should distribute reads between all available slaves" do
      master.should_receive(:get).never
      slaves[1].should_receive(:get).twice
      slaves[0].should_receive(:get).once

      3.times { subject.get "foo" }
    end
  end

  context "when in a multi block" do
    it "sends all commands to the master" do
      master.should_receive(:get).twice

      subject.multi do
        2.times { subject.get "foo" }
      end
    end
  end

  context "when in a pipelined block" do
    it "sends all commands to the master" do
      master.should_receive(:get).twice

      subject.pipelined do
        2.times { subject.get "foo" }
      end
    end
  end

  context "commands that distribute to all nodes" do
    it "should distribute to each node" do
      master.should_receive(:select).once
      slaves.each {|slave| slave.should_receive(:select).once }
      subject.send(:select)
    end

    it "should set the DB on each node" do
      subject.select 4
      master.client.db.should == 4
      slaves[0].client.db.should == 4
      slaves[1].client.db.should == 4
    end

    it "should disconnect each client" do
      subject.disconnect
      !!master.client.connected?.should == false
      !!slaves[0].client.connected?.should == false
      !!slaves[1].client.connected?.should == false
    end
  end
end