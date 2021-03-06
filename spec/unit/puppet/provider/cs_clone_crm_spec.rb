require 'spec_helper'

describe Puppet::Type.type(:cs_clone).provider(:crm) do
  before do
    described_class.stubs(:command).with(:crm).returns 'crm'
  end

  context 'when getting instances' do
    let :instances do

      test_cib = <<-EOS
        <cib>
        <configuration>
          <resources>
            <clone id="p_keystone-clone">
              <primitive class="systemd" id="p_keystone" type="openstack-keystone">
                <meta_attributes id="p_keystone-meta_attributes"/>
                <operations/>
              </primitive>
              <meta_attributes id="p_keystone-clone-meta"/>
            </clone>
          </resources>
        </configuration>
        </cib>
      EOS

      described_class.expects(:block_until_ready).returns(nil)
      if Puppet::Util::Package.versioncmp(Puppet::PUPPETVERSION, '3.4') == -1
        Puppet::Util::SUIDManager.expects(:run_and_capture).with(['crm', 'configure', 'show', 'xml']).at_least_once.returns([test_cib, 0])
      else
        Puppet::Util::Execution.expects(:execute).with(['crm', 'configure', 'show', 'xml']).at_least_once.returns(
          Puppet::Util::Execution::ProcessOutput.new(test_cib, 0)
        )
      end
      instances = described_class.instances
    end

    it 'should have an instance for each <clone>' do
      expect(instances.count).to eq(1)
    end

    describe 'each instance' do
      let :instance do
        instances.first
      end

      it "is a kind of #{described_class.name}" do
        expect(instance).to be_a_kind_of(described_class)
      end

      it "is named by the <primitive>'s id attribute" do
        expect(instance.name).to eq("p_keystone-clone")
      end
    end
  end

  context 'when flushing' do
    def expect_update(pattern)
      instance.expects(:crm).with { |*args|
        if args.slice(0..2) == ['configure', 'load', 'update']
          expect(File.read(args[3])).to match(pattern)
          true
        else
          false
        end
      }
    end

    let :resource do
      Puppet::Type.type(:cs_clone).new(
        :name      => 'p_keystone-clone',
        :provider  => :crm,
        :primitive => 'p_keystone',
        :ensure    => :present)
    end

    let :instance do
      instance = described_class.new(resource)
      instance.create
      instance
    end

    it 'creates clone' do
        expect_update(/clone p_keystone-clone p_keystone/)
        instance.flush
    end

    it 'sets max clones' do
      instance.clone_max = 3
      expect_update(/clone-max=3/)
      instance.flush
    end

    it 'sets max node clones' do
      instance.clone_node_max = 3
      expect_update(/clone-node-max=3/)
      instance.flush
    end
    
    it 'sets notify_clones' do
      instance.notify_clones = :true
      expect_update(/notify=true/)
      instance.flush
    end

    it 'sets globally unique' do
      instance.globally_unique = :true
      expect_update(/globally-unique=true/)
      instance.flush
    end

    it 'sets ordered' do
      instance.ordered = :true
      expect_update(/ordered=true/)
      instance.flush
    end

    it 'sets interleave' do
      instance.interleave = :true
      expect_update(/interleave=true/)
      instance.flush
    end
  end

end
