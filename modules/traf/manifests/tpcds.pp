# == Class: traf::tpcds
#

# requires HDFS and Hive to be up and running.
class traf::tpcds {

  # TPC-DS data required for hive regression tests
  # read-only tables by the tests, so one-time operation

  # data set-up scripts
  file { '/usr/local/bin/load_tpcds_data.sh':
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/traf/tpcds/load_tpcds_data.sh',
  }
  file { '/usr/local/bin/init_hive_tpcds.sql':
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/traf/tpcds/init_hive_tpcds.sql',
  }

  $tools_dir  = '/var/lib/tpcds'
  $tools_file = "${tools_dir}/tpcds_tools.zip"
  $tools_url  = 'http://www.tpc.org/tpcds/dsgen/dsgen-download-files.asp?download_key=NaN'

  file { $tools_dir :
    ensure => directory,
    owner  => root,
    group  => root,
    mode   => '0755'
  }


  exec { 'download-tpc-ds':
    command => "/usr/bin/curl --output ${tools_file} ${tools_url}",
    creates => $tools_file,
    require => File[$tools_dir],
  }
  exec { 'unzip-tools':
    require => Exec['download-tpc-ds'],
    creates => "${tools_dir}/TPC-DS v1.3.0/tools",
    command => "/usr/bin/unzip -od ${tools_dir} ${tools_file}",
  }
  # for backward compatiblity for earlier tool installs, which had no "DS Tools" dir
  exec { 'check-DS':
    require => Exec['unzip-tools'],
    creates => "${tools_dir}/DS Tools",
    command => "/bin/ln -s ${tools_dir} '${tools_dir}/DS Tools'",
  }
  # for backward compatiblity - they changed the dir name yet again
  exec { 'check-TPC-DS':
    require => Exec['unzip-tools'],
    creates => "${tools_dir}/TPC-DS v1.3.0",
    command => "/bin/ln -s '${tools_dir}/DS Tools' '${tools_dir}/TPC-DS v1.3.0'",
  }
  exec { 'build-tools':
    require => Exec['check-DS'],
    creates => "${tools_dir}/TPC-DS v1.3.0/tools/dsdgen",
    command => "/usr/bin/make -C '${tools_dir}/TPC-DS v1.3.0/tools'",
  }
  exec { 'gen_and_load_data':
    require => [
      Exec['build-tools'],
      File['/usr/local/bin/load_tpcds_data.sh'],
    ],
    command => '/usr/local/bin/load_tpcds_data.sh',
    user    => 'hdfs',
    timeout => 600,
    cwd     => "${tools_dir}/TPC-DS v1.3.0/tools",
    unless  => '/usr/bin/hadoop dfs -ls /hive/tpcds',
  }
  exec { 'hive_tables':
    require => [
      Exec['gen_and_load_data'],
      File['/usr/local/bin/init_hive_tpcds.sql'],
      Package['hive'] ],
    command => '/usr/bin/hive -f /usr/local/bin/init_hive_tpcds.sql',
    unless  => "/usr/bin/hive -e 'describe household_demographics'",
  }
}

