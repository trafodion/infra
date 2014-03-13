# == Class: traf::cloudera
#
# Single-Node set-up, only useful for simple functional testing
# Installs & configures a subset of CDH4
class traf::cloudera (
   $hive_sql_pw = '',
) {

  
  class {'mysql::server':
        config_hash =>  {
         'root_password'  => 'insecure_slave',
         'default_engine' => 'MyISAM',
         'bind_address'   => '127.0.0.1',
        }
  }
  include mysql::server::account_security
  
 
  class { 'mysql::java': }
  mysql::db { 'metastore':
    user     => 'hive',
    charset  => 'latin1',
    password => $hive_sql_pw,
    host     => 'localhost',
    sql      => '/usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-0.9.0.mysql.sql',
       # For now Trafodion requires 0.9.0
    grant    => ['all'],   # lets see if autoschema works
       # if we need to be more restrictive, Hive docs say:
       #grant    => ['Select_priv','Insert_priv','Update_priv',
       #             'Delete_priv','Lock_tables_priv','Execute_priv'],
    require  => Package['hive'],
  }

  # Trafodion configuration for Hive
  file { '/etc/SQSystemDefaults.conf':
    owner => 'root',
    group => 'root',
    mode  => '0644',
    content => template('traf/SQSystemDefaults.conf.erb'),
  }


  if $::osfamily == 'RedHat' {
    # packages needed for a stand-alone node
    $packages = [
      'hadoop',
      'hadoop-hdfs',
      'hadoop-hdfs-namenode',
      'hadoop-hdfs-datanode',
      'hadoop-libhdfs',
      'hadoop-mapreduce',
      'hadoop-yarn',
      'hadoop-yarn-resourcemanager',
      'hadoop-yarn-nodemanager',
      'hadoop-client',
      'hbase',
      'hbase-master',
      'hbase-thrift',
      'hive',
      'zookeeper-server',
    ]

    file { '/etc/yum.repos.d/cloudera-cdh4.repo':
       owner => 'root',
       group => 'root',
       mode  => '0644',
       source => 'puppet:///modules/traf/cloudera/cloudera-cdh4.repo',
    }

    exec { 'cloudera rpm' :
       command   => '/bin/rpm --import http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera',
       unless    => '/bin/rpm -qa -qa gpg-pubkey* | grep -q gpg-pubkey-e8f86acd-4a418045',
       require   => File['/etc/yum.repos.d/cloudera-cdh4.repo'],
    }

    package { $packages:
        ensure => present,
	require => Exec['cloudera rpm'],
    }
  } # if RedHat

  exec { 'hadoop-conf':
     command  => '/bin/cp -r /etc/hadoop/conf.dist /etc/hadoop/conf.localtest;
      /usr/sbin/alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.localtest 50;
      /usr/sbin/alternatives --set hadoop-conf /etc/hadoop/conf.localtest',
     creates  => '/etc/hadoop/conf.localtest',
     require  => Package['hadoop'],
  }
  file { '/etc/hadoop/conf.localtest/core-site.xml':
     source => 'puppet:///modules/traf/cloudera/core-site.xml',
     require => Exec['hadoop-conf'],
  }
  file { '/etc/hadoop/conf.localtest/hdfs-site.xml':
     source => 'puppet:///modules/traf/cloudera/hdfs-site.xml',
     require => Exec['hadoop-conf'],
  }
  file { '/etc/hadoop/conf.localtest/mapred-site.xml':
     source => 'puppet:///modules/traf/cloudera/mapred-site.xml',
     require => Exec['hadoop-conf'],
  }
  file { '/etc/hadoop/conf.localtest/yarn-site.xml':
     source => 'puppet:///modules/traf/cloudera/yarn-site.xml',
     require => Exec['hadoop-conf'],
  }

  exec { 'hbase-conf':
     command  => '/bin/cp -r /etc/hbase/conf.dist /etc/hbase/conf.localtest;
      /usr/sbin/alternatives --install /etc/hbase/conf hbase-conf /etc/hbase/conf.localtest 50;
      /usr/sbin/alternatives --set hbase-conf /etc/hbase/conf.localtest',
     creates  => '/etc/hbase/conf.localtest',
     require  => Package['hbase'],
  }
  file { '/etc/hbase/conf.localtest/hbase-site.xml':
     owner => 'root',
     group => 'root',
     mode  => '0644',
     source => 'puppet:///modules/traf/cloudera/hbase-site.xml',
     require => Exec['hbase-conf'],
  }
  file { '/etc/hive/conf/hive-site.xml':
       owner => 'root',
       group => 'root',
       mode  => '0644',
       content => template('traf/hive-site.xml.erb'),
       require => Package['hive'],
  }
  file { '/usr/lib/hive/lib/mysql-connector-java.jar':
       owner => 'root',
       group => 'root',
       mode  => '0644',
       ensure  => link,
       target  => '/usr/share/java/mysql-connector-java.jar',
       require => [ Package['mysql-connector-java'], Package['hive'] ],
  }
  # as specified in hdfs-site.xml
  file { ['/data/dfs/name','/data/dfs/data']:
       owner => 'hdfs',
       group => 'hdfs',
       mode  => '0700',
       ensure => directory,
       require => Package['hadoop-hdfs'],
  }
  file { ['/data','/data/dfs']:
       owner => 'root',
       group => 'root',
       mode  => '0755',
       ensure => directory,
  }
  # format name hdfs when first created
  exec { 'namenode-format':
       command   => '/usr/bin/hdfs namenode -format -force',
       user      => 'hdfs',
       subscribe => File['/data/dfs/name'],
       refreshonly => true,
  }
  file { ['/var/log/hadoop-yarn','/var/log/hadoop-yarn/containers','/var/log/hadoop-yarn/apps']:
       owner => 'yarn',
       group => 'yarn',
       mode  => '0755',
       ensure => directory,
  }
  $hdfs_services = ['hadoop-hdfs-datanode','hadoop-hdfs-namenode']
  $yarn_services = ['hadoop-yarn-resourcemanager','hadoop-yarn-nodemanager']
  # HBase services are not started, since
  # Trafodion testing stops/starts them

  service { $hdfs_services:
      ensure => running,
      subscribe => [ 
         File['/etc/hadoop/conf.localtest/hdfs-site.xml'], 
         File['/etc/hadoop/conf.localtest/core-site.xml'], 
       ],
      require => [ 
	 Exec['namenode-format'],
       ],
  }
  service { $yarn_services:
      ensure => running,
      subscribe => [ 
         File['/etc/hadoop/conf.localtest/yarn-site.xml'], 
         File['/etc/hadoop/conf.localtest/mapred-site.xml'], 
       ],
      require => [ 
	 Exec['hdfs-tmp'],
	 Exec['hdfs-userhist'],
	 Exec['hdfs-yarnlog'],
       ],
  }
  exec { 'hdfs-tmp':
      command => '/usr/bin/hadoop fs -mkdir -p /tmp && /usr/bin/hadoop fs -chmod 1777 /tmp',
      unless  => '/usr/bin/hadoop fs -ls -d /tmp',
      user    => 'hdfs',
      require => Service[$hdfs_services],
  }
  # /user is specified in yarn-site.xml
  exec { 'hdfs-userhist':
      command => 
          '/usr/bin/hadoop fs -mkdir -p /user/history 
           /usr/bin/hadoop fs -chmod 1777 /user/history
	   /usr/bin/hadoop fs -chown yarn /user/history',
      unless  => '/usr/bin/hadoop fs -ls -d /user/history',
      user    => 'hdfs',
      require => Service[$hdfs_services],
  }
  exec { 'hdfs-yarnlog':
      command => 
          '/usr/bin/hadoop fs -mkdir -p /var/log/hadoop-yarn
	   /usr/bin/hadoop fs -chown yarn:mapred /var/log/hadoop-yarn',
      unless  => '/usr/bin/hadoop fs -ls -d /var/log/hadoop-yarn',
      user    => 'hdfs',
      require => Service[$hdfs_services],
  }
  exec { 'hdfs-jenkins':
      command => 
          '/usr/bin/hadoop fs -mkdir -p /user/jenkins
	   /usr/bin/hadoop fs -chown jenkins /user/jenkins',
      unless  => '/usr/bin/hadoop fs -ls -d /user/jenkins',
      user    => 'hdfs',
      require => [ Service[$hdfs_services],User['jenkins'] ]
  }
}

