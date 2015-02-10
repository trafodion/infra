# Make cloud user credentials available to all nodes

$cloud_auto_user=hiera('cloud_auto_user')
$cloud_auto_passwd=hiera('cloud_auto_passwd')

#
# Default: at least puppet running regularly and sysadmin access
#
node default {
  include traf::puppet_cron
  class { 'traf::server':
    sysadmins => hiera('sysadmins'),
  }
}

#
# Long lived servers:
#
node 'review.trafodion.org' {
  class { 'traf::review':
    github_oauth_token              => hiera('gerrit_github_token', 'XXX'),
    github_project_username         => hiera('github_project_username', 'username'),
    github_project_password         => hiera('github_project_password', 'XXX'),
    mysql_host                      => hiera('gerrit_mysql_host', 'localhost'),
    mysql_password                  => hiera('gerrit_mysql_password', 'XXX'),
    mysql_root_password             => hiera('gerrit_mysql_root_password', 'XXX'),
    email_private_key               => hiera('gerrit_email_private_key', 'XXX'),
    #gerritbot_password              => hiera('gerrit_gerritbot_password', 'XXX'),
    #gerritbot_ssh_rsa_key_contents      => hiera('gerritbot_ssh_rsa_key_contents', 'XXX'),
    #gerritbot_ssh_rsa_pubkey_contents   => hiera('gerritbot_ssh_rsa_pubkey_contents', 'XXX'),
    ssl_cert_file_contents          => hiera('gerrit_ssl_cert_file_contents', 'XXX'),
    ssl_key_file_contents           => hiera('gerrit_ssl_key_file_contents', 'XXX'),
    ssl_chain_file_contents         => hiera('ssl_chain_file_contents', 'XXX'),
    ssh_dsa_key_contents            => hiera('gerrit_ssh_dsa_key_contents', 'XXX'),
    ssh_dsa_pubkey_contents         => hiera('gerrit_ssh_dsa_pubkey_contents', 'XXX'),
    ssh_rsa_key_contents            => hiera('gerrit_ssh_rsa_key_contents', 'XXX'),
    ssh_rsa_pubkey_contents         => hiera('gerrit_ssh_rsa_pubkey_contents', 'XXX'),
    ssh_project_rsa_key_contents    => hiera('gerrit_project_ssh_rsa_key_contents', 'XXX'),
    ssh_project_rsa_pubkey_contents => hiera('gerrit_project_ssh_rsa_pubkey_contents', 'XXX'),
    ssh_welcome_rsa_key_contents    => hiera('welcome_message_gerrit_ssh_private_key', 'XXX'),
    ssh_welcome_rsa_pubkey_contents => hiera('welcome_message_gerrit_ssh_public_key', 'XXX'),
    #Key for replicating to cgit servers
    #ssh_replication_rsa_key_contents    => hiera('gerrit_replication_ssh_rsa_key_contents', 'XXX'),
    #ssh_replication_rsa_pubkey_contents => hiera('gerrit_replication_ssh_rsa_pubkey_contents', 'XXX'),
    lp_sync_consumer_key            => hiera('gerrit_lp_consumer_key', 'XXX'),
    lp_sync_token                   => hiera('gerrit_lp_access_token', 'XXX'),
    lp_sync_secret                  => hiera('gerrit_lp_access_secret', 'XXX'),
    # Don't store committer contact information
    #contactstore_appsec             => hiera('gerrit_contactstore_appsec', 'XXX'),
    #contactstore_pubkey             => hiera('gerrit_contactstore_pubkey', 'XXX'),
    sysadmins                       => hiera('sysadmins', ['admins']),
    # Needed for openstackwatch -- No twitter feeds yet
    #swift_username                  => hiera('swift_store_user'),
    #swift_password                  => hiera('swift_store_key'),
  }
}

# Jenkins master for US West
node 'jenkins01.trafodion.org' {
  class { 'traf::jenkins':
    jenkins_jobs_password   => hiera('jenkins_jobs_password'),
    jenkins_ssh_private_key => hiera('jenkins_ssh_private_key_contents'),
    ssl_cert_file_contents  => hiera('jenkins01_ssl_cert_file_contents'),
    ssl_key_file_contents   => hiera('jenkins01_ssl_key_file_contents'),
    ssl_chain_file_contents => hiera('ssl_chain_file_contents'),
    sysadmins               => hiera('sysadmins'),
    #zmq_event_receivers     => ['logstash.openstack.org',],
    #zmq_event_receivers     => ['nodepool.trafodion.org',
    #],
  }
}

# Jenkins master for US East
node 'jenkins02.trafodion.org' {
  class { 'traf::jenkins':
    jenkins_jobs_password   => hiera('jenkins02_jobs_password'),
    jenkins_ssh_private_key => hiera('jenkins_ssh_private_key_contents'),
    ssl_cert_file_contents  => hiera('jenkins02_ssl_cert_file_contents'),
    ssl_key_file_contents   => hiera('jenkins02_ssl_key_file_contents'),
    ssl_chain_file_contents => hiera('ssl_chain_file_contents'),
    sysadmins               => hiera('sysadmins'),
    #zmq_event_receivers     => ['logstash.openstack.org',],
    #zmq_event_receivers     => ['nodepool.trafodion.org',
    #],
  }
}

node 'puppet.trafodion.org' {
  class { 'traf::puppetmaster':
    sysadmins         => hiera('sysadmins'),
  }
}

node 'wiki.trafodion.org' {
  class { 'traf::wiki':
    wiki_admin_password     => hiera('wiki_admin_password'),
    mysql_root_password     => hiera('wiki_db_password'),
    sysadmins               => hiera('sysadmins'),
    ssl_cert_file_contents  => hiera('wiki_ssl_cert_file_contents'),
    ssl_key_file_contents   => hiera('wiki_ssl_key_file_contents'),
    ssl_chain_file_contents => hiera('wiki_ssl_chain_file_contents'),
  }
}

# wiki for Beta Access (no anonymous access)
node 'wiki2.trafodion.org' {
  class { 'traf::wiki':
    wiki_admin_password     => hiera('wiki_admin_password'),
    mysql_root_password     => hiera('wiki_db_password'),
    sysadmins               => hiera('sysadmins'),
    ssl_cert_file_contents  => hiera('wiki_ssl_cert_file_contents'),
    ssl_key_file_contents   => hiera('wiki_ssl_key_file_contents'),
    ssl_chain_file_contents => hiera('wiki_chain_file_contents'),
  }
}

node 'dashboard.trafodion.org' {
  class { 'traf::dashboard':
    password       => hiera('dashboard_password'),
    mysql_password => hiera('dashboard_mysql_password'),
    sysadmins      => hiera('sysadmins'),
  }
}

# nodepool removed - may use in future

node 'zuul.trafodion.org' {
  class { 'traf::zuul_prod':
    gerrit_server                  => 'review.trafodion.org',
    gerrit_user                    => 'jenkins',
    gerrit_ssh_host_key            => hiera('gerrit_ssh_rsa_pubkey_contents', 'XXX'),
    zuul_ssh_private_key           => hiera('zuul_ssh_private_key_contents', 'XXX'),
    url_pattern                    => 'http://logs.trafodion.org/{build.parameters[LOG_PATH]}',
    #swift_authurl                  => 'https://identity.api.rackspacecloud.com/v2.0/',
    #swift_user                     => 'infra-files-rw',
    #swift_key                      => hiera('infra_files_rw_password', 'XXX'),
    #swift_tenant_name              => hiera('infra_files_tenant_name', 'tenantname'),
    #swift_region_name              => 'DFW',
    #swift_default_container        => 'infra-files',
    swift_default_logserver_prefix => 'http://logs.trafodion.org/',
    zuul_url                       => 'http://zuul.trafodion.org/p',
    sysadmins                      => hiera('sysadmins', ['admin']),
    #statsd_host                    => 'graphite.trafodion.org',
    gearman_workers                => [
      '15.126.225.210',
      '15.125.67.186',
      '192.168.0.34',
    ],
    gearman6_workers               => [
      '0:0:0:0:0:ffff:f7e:e1d2',
      '0:0:0:0:0:ffff:f7d:43ba',
      '0:0:0:0:0:ffff:c0a8:22'
    ],
  }
}

# A machine to serve static content.
# For instance, domain home page, ftp server, etc.
node 'static.trafodion.org' {
  class { 'traf::static':
    sysadmins                     => hiera('sysadmins'),
    reviewday_rsa_key_contents    => hiera('reviewday_rsa_key_contents'),
    reviewday_rsa_pubkey_contents => hiera('reviewday_rsa_pubkey_contents'),
    reviewday_gerrit_ssh_key      => hiera('gerrit_ssh_rsa_pubkey_contents'),
    releasestatus_prvkey_contents => hiera('releasestatus_rsa_key_contents'),
    releasestatus_pubkey_contents => hiera('releasestatus_rsa_pubkey_contents'),
    releasestatus_gerrit_ssh_key  => hiera('gerrit_ssh_rsa_pubkey_contents'),
  }
}

# Zuul status page needs graphite
node 'graphite.trafodion.org' {
  class { 'traf::graphite':
    sysadmins               => hiera('sysadmins'),
    graphite_admin_user     => hiera('graphite_admin_user'),
    graphite_admin_email    => hiera('graphite_admin_email'),
    graphite_admin_password => hiera('graphite_admin_password'),
    statsd_hosts            => [
#                                'nodepool.openstack.org',
                                'zuul.trafodion.org'],
  }
}

#
# Jenkins slaves:
#

# Cloudera5.1
node /^slave-cdh51-\d\d.trafodion.org$/ {
  include traf
  include traf::puppet_cron
  class { 'traf::slave':
    ssh_key     => $traf::jenkins_ssh_key,
    logs_host   => hiera('static_host_key'),
    sysadmins   => hiera('sysadmins'),
    hive_sql_pw => hiera('hive_sql_pw'),
    distro      => 'CDH5.1',
  }
}

# CMgr
node /^slave-cm51-\d\d.trafodion.org$/ {
  include traf
  include traf::puppet_cron
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'CM5.1',
  }
}

# Ambari HortonWorks
node /^slave-ahw21-\d\d.trafodion.org$/ {
  include traf
  include traf::puppet_cron
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'AHW2.1',
  }
}


# vim:sw=2:ts=2:expandtab:textwidth=79
