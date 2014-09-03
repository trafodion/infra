# == Class: traf::tpcds
#
class traf::tpcds (
  $namenodeserv = 'hadoop-hdfs-namenode',
  $datanodeserv = 'hadoop-hdfs-datanode',
) {

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
  $tools_file = "$tools_dir/tpcds_tools.zip"
  $tools_url  = 'http://www.tpc.org/tpcds/dsgen/dsgen-download-files.asp?download_key=NaN'

  file { $tools_dir :
    ensure => directory,
    owner  => root,
    group  => root,
    mode   => '0755'
  }


  exec { 'download-tpc-ds':
    command  => "/usr/bin/curl --output $tools_file $tools_url",
    creates  => $tools_file,
    require  => File[$tools_dir],
  }
  exec { 'unzip-tools':
    require  => Exec['download-tpc-ds'],
    creates  => "$tools_dir/tools",
    command  => "/usr/bin/unzip -d $tools_dir $tools_file",
  }
  exec { 'build-tools':
    require  => Exec['unzip-tools'],
    creates  => "$tools_dir/tools/dsdgen",
    command  => "/usr/bin/make -C $tools_dir/tools",
  }
  exec { 'gen_and_load_data':
    require  => [ Exec['build-tools'],
                  File['/usr/local/bin/load_tpcds_data.sh'],
                  Service[$namenodeserv],
                  Service[$datanodeserv] ],
    command  => "/usr/local/bin/load_tpcds_data.sh",
    user     => 'hdfs',
    timeout  => 600,
    cwd      => "$tools_dir/tools",
    unless   => "/usr/bin/hadoop dfs -ls /hive/tpcds",
  }
  exec { 'hive_tables':
    require  => [
      Exec['gen_and_load_data'],
      File['/usr/local/bin/init_hive_tpcds.sql'],
      Package['hive'] ],
    command  => "/usr/bin/hive -f /usr/local/bin/init_hive_tpcds.sql",
    unless   => "/usr/bin/hive -e 'describe household_demographics'",
  }
}

