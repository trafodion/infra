# == Class: traf::hive_metastore
#
# Single-Node set-up of mysql metastore DB for Hive
# Common for multiple distros
#
# Requires hive to be installed first. Be sure to set up dependency appropriate for hive install method.
class traf::hive_metastore (
  $hive_sql_pw = '',
  $hive_schema_ver = '0.9.0',
  $hive_home = '/usr/lib/hive',
) {

  class {'mysql::server':
    root_password    => 'insecure_slave',
    override_options =>  {
      'mysqld' => {
        'default_storage_engine' => 'MyISAM',
        'bind_address'           => '127.0.0.1',
      }
    }
  }
  include mysql::server::account_security


  class { 'mysql::bindings':
    java_enable  => true,
  }

  mysql::db { 'metastore':
    user     => 'hive',
    charset  => 'latin1',
    collate  => 'latin1_swedish_ci',
    password => $hive_sql_pw,
    host     => 'localhost',
    sql      => "${hive_home}/scripts/metastore/upgrade/mysql/hive-schema-${hive_schema_ver}.mysql.sql",
    grant    => ['all'],
  }

  file { "${hive_home}/lib/mysql-connector-java.jar":
    ensure  => link,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    target  => '/usr/share/java/mysql-connector-java.jar',
    require => Class['mysql::bindings'],
  }
}

