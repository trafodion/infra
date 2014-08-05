# == Class: traf::horton_slave
#
class traf::horton_slave (
  $bare = false,
  $certname = $::fqdn,
  $ssh_key = '',
  $sysadmins = [],
  $python3 = false,
  $include_pypy = false,
  $hive_sql_pw = '',
) {
  include traf
  include traf::buildtest
  include traf::tmpcleanup
  class { 'traf::tpcds':
    namenodeserv => 'hadoop-namenode',
    datanodeserv => 'hadoop-datanode',
  }


  class { 'traf::slave':
    bare         => $bare,
    certname     => $certname,
    ssh_key      => $ssh_key,
    sysadmins    => $sysadmins,
    python3      => $python3,
    include_pypy => $include_pypy,
  }

  class { 'traf::horton':
    hive_sql_pw => $hive_sql_pw,
  }
}
