require 'spec_helper'

describe 'windows_dhcp::failover', :type => :define do
  let(:default_exec) {{
    :provider => 'powershell',
    :require  => 'Exec[add DHCPSERVER <-> REMOTESERVER]'
  }}
  let(:default_params) {{
    # required parameters
    :partnerserver       => 'REMOTESERVER.CONTOSO.LOCAL',
    :scopeid             => '192.168.10.0',
    # default parameters
    :mode                => 'loadbalance',
    :loadbalancepercent  => 50,
    :maxclientleadtime   => '1:00:00',
    :reservepercent      => 5,
    :serverrole          => 'active',
    :stateswitchinterval => '1:00:00',
  }}
  let(:facts) {{
    :fqdn            => 'DHCPSERVER.CONTOSO.LOCAL',
    :kernel          => 'Windows',
    :kernelversion   => '6.2',
    :osfamily        => 'Windows',
    :operatingsystem => 'Windows',
  }}
  let(:title) { 'DHCPSERVER <-> REMOTESERVER' }

  context "when creating a failover relationship with minimum parameters" do
    let(:params) { default_params }
    it { should contain_windows_dhcp__failover(title) }

    common_options = "-AutoStateTransition \$true -MaxClientLeadTime 1:00:00 -SharedSecret \"\" -StateSwitchInterval 1:00:00"
    mode_options   = "-LoadBalancePercent 50"

    # Not supported at this time, see https://github.com/rodjek/rspec-puppet/issues/192
    # it { should compile.with_all_deps }

    it { should contain_exec('add DHCPSERVER <-> REMOTESERVER').with(
      :command  => "Add-DhcpServerv4Failover -Name \"DHCPSERVER <-> REMOTESERVER\" -ScopeId 192.168.10.0 -PartnerServer REMOTESERVER.CONTOSO.LOCAL #{common_options} #{mode_options} -Force",
      :unless   => "if (Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\") { exit 0 } else { exit 1 }",
      :provider => 'powershell',
      :require  => nil,
    )}

    it { should contain_file('Update-DhcpServerv4FailoverScope.ps1').with(
      :ensure => 'present',
      :path   => 'C:/Windows/Temp/Update-DhcpServerv4FailoverScope.ps1',
      :source => 'puppet:///modules/windows_dhcp/Update-DhcpServerv4FailoverScope.ps1',
    )}
  end

  ['loadbalance', 'hotstandby'].each do |mode|
    context "when mode is set to \'#{mode}\'" do
      describe "and creating a failover relationship with default parameters" do
        let(:params) { default_params.merge({ :mode => mode }) }

        # opt == 'loadbalance' ? mode_options = "-LoadBalancePercent 50" : mode_options = "-ReservePercent 5 -ServerRole active"
        common_options = "-AutoStateTransition \$true -MaxClientLeadTime 1:00:00 -SharedSecret \"\" -StateSwitchInterval 1:00:00"
        mode_options   = mode == 'loadbalance' ? "-LoadBalancePercent 50" : "-ReservePercent 5 -ServerRole active"

        it { should contain_windows_dhcp__failover(title) }

        # Not supported at this time, see https://github.com/rodjek/rspec-puppet/issues/192
        # it { should compile.with_all_deps }

        it { should contain_exec('add DHCPSERVER <-> REMOTESERVER').with(
          :command  => "Add-DhcpServerv4Failover -Name \"DHCPSERVER <-> REMOTESERVER\" -ScopeId 192.168.10.0 -PartnerServer REMOTESERVER.CONTOSO.LOCAL #{common_options} #{mode_options} -Force",
          :unless   => "if (Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\") { exit 0 } else { exit 1 }",
          :provider => 'powershell',
          :require  => nil,
        )}

        it { should contain_file('Update-DhcpServerv4FailoverScope.ps1').with(
          :ensure => 'present',
          :path   => 'C:/Windows/Temp/Update-DhcpServerv4FailoverScope.ps1',
          :source => 'puppet:///modules/windows_dhcp/Update-DhcpServerv4FailoverScope.ps1',
        )}
      end

      other_mode = mode == "loadbalance" ? "hotstandby" : "loadbalance"

      context "and mode is changed to \'#{other_mode}\'" do
        let(:params) { default_params.merge({ :mode => other_mode }) }

        it { should contain_exec('set DHCPSERVER <-> REMOTESERVER mode').with(default_exec.merge(
          :command  => "Set-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\" -Mode #{other_mode}",
          :unless   => "if ((Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\").Mode -ne #{other_mode}) { exit 1 }",
          :provider => 'powershell',
          :require  => 'Exec[add DHCPSERVER <-> REMOTESERVER]'
        ))}
      end

      describe "and scopeid is changed to \'192.168.10.0\'" do
        let(:params) { default_params.merge({ :mode => mode, :scopeid => '192.168.10.0' })}

        it { should contain_exec('set DHCPSERVER <-> REMOTESERVER subnets').with(default_exec.merge(
          :command => "C:/Windows/Temp/Update-DhcpServerv4FailoverScope.ps1' -Name \"DHCPSERVER <-> REMOTESERVER\" -ScopeId 192.168.10.0",
          :unless  => "if ((Compare-Object (Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\").ScopeId 192.168.10.0).count -gt 0) { write 1 }",
          :require => ['Exec[add DHCPSERVER <-> REMOTESERVER]', 'File[Update-DhcpServerv4FailoverScope.ps1]'],
        ))}
      end

      describe "and scopeid is changed to \'[192.168.10.0, 192.168.20.0]\'" do
        let(:params) { default_params.merge({ :mode => mode, :scopeid => ['192.168.10.0','192.168.20.0'] })}

        it { should contain_exec('set DHCPSERVER <-> REMOTESERVER subnets').with(default_exec.merge(
          :command => "C:/Windows/Temp/Update-DhcpServerv4FailoverScope.ps1' -Name \"DHCPSERVER <-> REMOTESERVER\" -ScopeId @('192.168.10.0','192.168.20.0')",
          :unless  => "if ((Compare-Object (Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\").ScopeId @('192.168.10.0','192.168.20.0')).count -gt 0) { write 1 }",
          :require => ['Exec[add DHCPSERVER <-> REMOTESERVER]', 'File[Update-DhcpServerv4FailoverScope.ps1]'],
        ))}
      end

      context "and loadbalancepercent is changed to \'50\'" do
        let(:params) { default_params.merge({ :mode => mode, :loadbalancepercent => 50 }) }

        if mode == 'loadbalance'
          it { should contain_exec('set DHCPSERVER <-> REMOTESERVER loadbalancepercent').with(default_exec.merge(
            :command  => 'Set-DhcpServerv4Failover "DHCPSERVER <-> REMOTESERVER" -LoadBalancePercent 50',
            :unless   => 'if ((Get-DhcpServerv4Failover "DHCPSERVER <-> REMOTESERVER").LoadBalancePercent -ne 50) { exit 1 }',
          ))}
        else
          it { should_not contain_exec('set DHCPSERVER <-> REMOTESERVER loadbalancepercent').with(default_exec.merge(
            :command  => 'Set-DhcpServerv4Failover "DHCPSERVER <-> REMOTESERVER" -LoadBalancePercent 50',
            :unless   => 'if ((Get-DhcpServerv4Failover "DHCPSERVER <-> REMOTESERVER").LoadBalancePercent -ne 50) { exit 1 }',
          ))}
        end
      end

      context "and maxclientleadtime is changed to \'1:00:00\'" do
        let(:params) { default_params.merge({ :mode => mode, :maxclientleadtime => '1:00:00' }) }

        it { should contain_exec('set DHCPSERVER <-> REMOTESERVER maxclientleadtime').with(default_exec.merge(
          :command  => "Set-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\" -MaxClientLeadTime 1:00:00",
          :unless   => "if ((Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\").MaxClientLeadTime -ne \"1:00:00\") { exit 1 }",
        ))}
      end

      context "and reservepercent is changed to \'5\'" do
        let(:params) { default_params.merge({ :mode => mode, :reservepercent => 5 }) }

        if mode == 'loadbalance'
          it { should_not contain_exec('set DHCPSERVER <-> REMOTESERVER reservepercent').with(default_exec.merge(
            :command  => 'Set-DhcpServerv4Failover "DHCPSERVER <-> REMOTESERVER" -ReservePercent 5',
            :unless   => 'if ((Get-DhcpServerv4Failover DHCPSERVER <-> REMOTESERVER).ReservePercent -ne 5) { exit 1 }',
          ))}
        else
          it { should contain_exec('set DHCPSERVER <-> REMOTESERVER reservepercent').with(default_exec.merge(
            :command  => 'Set-DhcpServerv4Failover "DHCPSERVER <-> REMOTESERVER" -ReservePercent 5',
            :unless   => 'if ((Get-DhcpServerv4Failover "DHCPSERVER <-> REMOTESERVER").ReservePercent -ne 5) { exit 1 }',
          ))}
        end
      end

      ['active', 'standby'].each do |role|
        context "and serverrole is changed to \'#{role}\'" do
          let(:params) { default_params.merge({ :mode => mode, :serverrole => role }) }

          if mode == 'loadbalance'
            it { should_not contain_exec('set DHCPSERVER <-> REMOTESERVER serverrole').with(default_exec.merge(
              :command  => "Set-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\" -ServerRole #{role}",
              :unless   => "if ((Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\").ServerRole -ne #{role}) { exit 1 }",
            ))}
          else
            it { should contain_exec('set DHCPSERVER <-> REMOTESERVER serverrole').with(default_exec.merge(
              :command  => "Set-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\" -ServerRole #{role}",
              :unless   => "if ((Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\").ServerRole -ne #{role}) { exit 1 }",
            ))}
          end
        end
      end

      ['0', '1:00:00'].each do |interval|
        context "and stateswitchinterval is changed to \"#{interval}\"" do
          let(:params) { default_params.merge({ :mode => mode, :stateswitchinterval => interval }) }

          autostatetransition = interval == '0' ? '$false' : '$true'

          it { should contain_exec('set DHCPSERVER <-> REMOTESERVER stateswitchinterval').with(default_exec.merge(
            :command  => "Set-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\" -StateSwitchInterval #{interval}",
            :unless   => "if ((Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\").StateSwitchInterval -ne #{interval}) { exit 1 }",
          ))}

          it { should contain_exec('set DHCPSERVER <-> REMOTESERVER autostatetransition').with(default_exec.merge(
            :command  => "Set-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\" -AutoStateTransition #{autostatetransition}",
            :unless   => "if ((Get-DhcpServerv4Failover \"DHCPSERVER <-> REMOTESERVER\").AutoStateTransition -ne #{autostatetransition}) { exit 1 }",
          ))}
        end
      end
    end

  end
end
