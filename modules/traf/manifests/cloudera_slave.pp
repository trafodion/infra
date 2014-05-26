# == Class: traf::cloudera_slave
#
class traf::cloudera_slave (
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
  include traf::tpcds

  class { 'traf::slave':
    bare         => $bare,
    certname     => $certname,
    ssh_key      => $ssh_key,
    sysadmins    => $sysadmins,
    python3      => $python3,
    include_pypy => $include_pypy,
  }

  class { 'traf::cloudera':
    hive_sql_pw => $hive_sql_pw,
  }
}
