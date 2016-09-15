#! /usr/bin/env ruby -S rspec
require 'spec_helper_acceptance'

describe 'corosync' do
  cert = '-----BEGIN CERTIFICATE-----
MIIDVzCCAj+gAwIBAgIJAJNCo5ZPmKegMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNV
BAYTAlhYMRUwEwYDVQQHDAxEZWZhdWx0IENpdHkxHDAaBgNVBAoME0RlZmF1bHQg
Q29tcGFueSBMdGQwHhcNMTUwMjI2MjI1MjU5WhcNMTUwMzI4MjI1MjU5WjBCMQsw
CQYDVQQGEwJYWDEVMBMGA1UEBwwMRGVmYXVsdCBDaXR5MRwwGgYDVQQKDBNEZWZh
dWx0IENvbXBhbnkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
uCPPbDgErGUVs1pKqv59OatjCEU4P9QcmhDYFR7RBN8m08mIqd+RTuiHUKj6C9Rk
vWQ5bYrGQo/+4E0ziAUuUzzITlpIYLVltca6eBhKUqO3Cd0NMRVc2k4nx5948nwv
9FVOIfOOY6BN2ALglfBfLnhObbzJjs6OSZ7bUCpXVPV01t/61Jj3jQ3+R8b7AaoR
mw7j0uWaFimKt/uag1qqKGw3ilieMhHlG0Da5x9WLi+5VIM0t1rcpR58LLXVvXZB
CrQBucm2xhZsz7R76Ai+NL8zhhyzCZidZ2NtJ3E1wzppcSDAfNrru+rcFSlZ4YG+
lMCqZ1aqKWVXmb8+Vg7IkQIDAQABo1AwTjAdBgNVHQ4EFgQULxI68KhZwEF5Q9al
xZmFDR+Beu4wHwYDVR0jBBgwFoAULxI68KhZwEF5Q9alxZmFDR+Beu4wDAYDVR0T
BAUwAwEB/zANBgkqhkiG9w0BAQUFAAOCAQEAsa0YKPixD6VmDo3pal2qqichHbdT
hUONk2ozzRoaibVocqKx2T6Ho23wb/lDlRUu4K4DMO663uumzI9lNoOewa0MuW1D
J52cejAMVsP3ROOdxBv0HZIVVJ8NLBHNLFOHJEDtvzogLVplzmo59vPAdmQo6eIV
japvs+0tdy9iwHj3z1ZME2Ntm/5TzG537e7Hb2zogatM9aBTUAWlZ1tpoaXuTH52
J76GtqoIOh+CTeY/BMwBotdQdgeR0zvjE9FuLWkhTmRtVFhbVIzJbFlFuYq5d3LH
NWyN0RsTXFaqowV1/HSyvfD7LoF/CrmN5gOAM3Ierv/Ti9uqGVhdGBd/kw=='
  File.open('/tmp/ca.pem', 'w') { |f| f.write(cert) }
  it 'with defaults' do
    pp = <<-EOS
      file { '/tmp/ca.pem':
        ensure  => file,
        content => '#{cert}'
      } ->
      class { 'corosync':
        multicast_address => '224.0.0.1',
        authkey           => '/tmp/ca.pem',
        bind_address      => '127.0.0.1',
        set_votequorum    => true,
        quorum_members    => ['127.0.0.1'],
      }
      cs_property { 'stonith-enabled' :
        value   => 'false',
      } ->
      cs_primitive { 'duncan_vip':
        primitive_class => 'ocf',
        primitive_type  => 'IPaddr2',
        provided_by     => 'heartbeat',
        parameters      => { 'ip' => '172.16.210.101', 'cidr_netmask' => '24' },
        operations      => { 'monitor' => { 'interval' => '10s' } },
      }
    EOS

    apply_manifest(pp, catch_failures: true, debug: true, trace: true)
    apply_manifest(pp, catch_changes: true, debug: false, trace: true)
  end

  describe service('corosync') do
    it { is_expected.to be_running }
  end

  it 'creates a clone' do
    pp = <<-EOS
         cs_clone { 'duncan_vip_clone':
           ensure => present,
           primitive => 'duncan_vip',
         }
         EOS
    apply_manifest(pp, catch_failures: true, debug: true, trace: true)
    apply_manifest(pp, catch_changes: true, debug: false, trace: true)
    command = 'cibadmin --query | grep duncan_vip_clone'
    shell(command) do |r|
      expect(r.stdout).to match(%r{<clone})
    end
  end

  it 'deletes a clone' do
    pp = <<-EOS
         cs_clone { 'duncan_vip_clone':
           ensure => absent,
         }
         EOS
    apply_manifest(pp, catch_failures: true, debug: true, trace: true)
    apply_manifest(pp, catch_changes: true, debug: false, trace: true)
    command = 'cibadmin --query | grep duncan_vip_clone'
    assert_raises(Beaker::Host::CommandFailure) do
      shell(command)
    end
  end

  context 'with all the parameters' do
    let(:fetch_clone_command) { 'cibadmin --query --xpath /cib/configuration/resources/clone[@id="duncan_vip_complex_clone"]' }
    it 'creates the clone' do
      pp = <<-EOS
         cs_clone { 'duncan_vip_complex_clone':
           ensure => present,
           primitive => 'duncan_vip',
           clone_max => 42,
           clone_node_max => 2,
           notify_clones => false,
           globally_unique => true,
           ordered => false,
           interleave => false,
         }
      EOS
      apply_manifest(pp, catch_failures: true, debug: true, trace: true)
      apply_manifest(pp, catch_changes: true, debug: false, trace: true)
      shell(fetch_clone_command) do |r|
        expect(r.stdout).to match(%r{<clone})
      end
    end

    it 'sets clone_max' do
      shell(fetch_clone_command) do |r|
        expect(r.stdout).to match(%r{clone-max="42"})
      end
    end

    it 'sets clone_node_max' do
      shell(fetch_clone_command) do |r|
        expect(r.stdout).to match(%r{clone-node-max="2"})
      end
    end

    it 'sets notify_clones' do
      shell(fetch_clone_command) do |r|
        expect(r.stdout).to match(%r{notify="false"})
      end
    end

    it 'sets globally_unique' do
      shell(fetch_clone_command) do |r|
        expect(r.stdout).to match(%r{globally-unique="true"})
      end
    end

    it 'sets ordered' do
      shell(fetch_clone_command) do |r|
        expect(r.stdout).to match(%r{ordered="false"})
      end
    end

    it 'sets interleave' do
      shell(fetch_clone_command) do |r|
        expect(r.stdout).to match(%r{interleave="false"})
      end
    end
  end

  after :all do
    cleanup_cs_resources
  end
end
