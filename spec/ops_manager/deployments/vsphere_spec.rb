require 'spec_helper'

describe OpsManager::Deployments::Vsphere do
  let(:conf_file){'ops_manager_deployment.yml'}
  let(:conf){ YAML.load_file(conf_file) }
  let(:name){ conf.fetch('name') }
  let(:version){ conf.fetch('version') }
  let(:target){ conf.fetch('ip') }
  let(:username){ conf.fetch('username') }
  let(:password){ conf.fetch('password') }
  let(:vcenter_username){ vcenter.fetch('username') }
  let(:vcenter_password){ vcenter.fetch('password') }
  let(:vcenter_datacenter){ vcenter.fetch('datacenter') }
  let(:vcenter_cluster){ vcenter.fetch('cluster') }
  let(:vcenter_host){ vcenter.fetch('host') }
  let(:vcenter){ opts.fetch('vcenter') }
  let(:opts){ conf.fetch('opts') }
  let(:current_version){ '1.4.2.0' }
  let(:current_vm_name){ "#{name}-#{vsphere.current_version}"}
  let(:new_vm_name){ "#{name}-#{version}"}
  let(:vsphere){ described_class.new(name, version, opts) }

  before do
    OpsManager.set_conf(:target, '1.2.3.4')
    OpsManager.set_conf(:username, 'foo')
    OpsManager.set_conf(:username, 'bar')
  end

  it 'should inherit from deployment' do
    expect(described_class).to be < OpsManager::Deployments::Base
  end

  it 'should include logging' do
    expect(vsphere).to be_kind_of(OpsManager::Logging)
  end

  describe 'deploy_vm' do
    let(:vcenter_target){"vi://#{vcenter_username}:#{vcenter_password}@#{vcenter_host}/#{vcenter_datacenter}/host/#{vcenter_cluster}"}

    it 'should run ovftools successfully' do
      allow(vsphere).to receive(:current_version).and_return(current_version)
      expect(vsphere).to receive(:`).with("echo yes | ovftool --acceptAllEulas --noSSLVerify --powerOn --X:waitForIp --net:\"Network 1=#{opts['portgroup']}\" --name=#{new_vm_name} -ds=#{opts['datastore']} --prop:ip0=#{target} --prop:netmask0=#{opts['netmask']}  --prop:gateway=#{opts['gateway']} --prop:DNS=#{opts['dns']} --prop:ntp_servers=#{opts['ntp_servers'].join(',')} --prop:admin_password=#{password} #{opts['ova_path']} #{vcenter_target}")
      vsphere.deploy_vm
    end

    %w{username password}.each do |m|
      describe "when vcenter_#{m} has unescaped character" do
        before { opts['vcenter'][m] = "domain\\vcenter_#{m}" }

        it "should URL encode the #{m}" do
          expect(vsphere).to receive(:`).with(/domain%5Cvcenter_#{m}/)
          vsphere.deploy_vm
        end
      end
    end
  end

  describe 'stop_current_vm' do
    before { allow(vsphere).to receive(:current_version).and_return(current_version) }

    it 'should stops current vm to release IP' do
      VCR.use_cassette 'stopping vm' do
        expect(RbVmomi::VIM).to receive(:connect).with({ host: vcenter_host, user: vcenter_username , password: vcenter_password , insecure: true}).and_call_original
        expect_any_instance_of(RbVmomi::VIM::ServiceInstance).to receive(:find_datacenter).with(vcenter_datacenter).and_call_original
        expect_any_instance_of(RbVmomi::VIM::Datacenter).to receive(:find_vm).with(current_vm_name).and_call_original
        expect_any_instance_of(RbVmomi::VIM::VirtualMachine).to receive(:PowerOffVM_Task).and_call_original
        vsphere.stop_current_vm
      end
    end
  end
end