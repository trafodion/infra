# Class: mediawiki
#
class mediawiki(
  $role = '',
  $site_hostname = '',
  $site_hostname_alias = '',
  $server_admin = '',
  $mediawiki_location = '',
  $mediawiki_images_location = '',
  $ssl_cert_file = "/etc/ssl/certs/${::fqdn}.pem",
  $ssl_key_file = "/etc/ssl/private/${::fqdn}.key",
  $ssl_chain_file = '',
  $ssl_cert_file_contents = '', # If left empty puppet will not create file.
  $ssl_key_file_contents = '',  # If left empty puppet will not create file.
  $ssl_chain_file_contents = '' # If left empty puppet will not create file.
) {

  if ($role == 'app' or $role == 'all') {
    # Must install this by hand until puppet module updated LP bug 1430528
    #require apache::dev
    include apache
    include mediawiki::php
    include mediawiki::app

    package { ['libapache2-mod-php5',
      'lua5.2']:
      ensure => present,
    }

    if $ssl_cert_file_contents != '' {
      file { $ssl_cert_file:
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        content => $ssl_cert_file_contents,
        before  => Apache::Vhost[$site_hostname],
      }
    }

    if $ssl_key_file_contents != '' {
      file { $ssl_key_file:
        owner   => 'root',
        group   => 'ssl-cert',
        mode    => '0640',
        content => $ssl_key_file_contents,
        before  => Apache::Vhost[$site_hostname],
      }
    }

    if $ssl_chain_file_contents != '' {
      file { $ssl_chain_file:
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        content => $ssl_chain_file_contents,
        before  => Apache::Vhost[$site_hostname],
      }
    }

    apache::vhost { $site_hostname:
      port     => 443,
      docroot  => 'MEANINGLESS ARGUMENT',
      priority => '50',
      template => 'mediawiki/apache/mediawiki.erb',
      ssl      => true,
    }
    a2mod { 'rewrite':
      ensure => present,
    }
    a2mod { 'expires':
      ensure => present,
    }
    a2mod { 'headers':
      ensure => present,
    }
  }
  if ($role == 'image-scaler' or $role == 'all') {
    include mediawiki::image_scaler
    include mediawiki::php
    include mediawiki::app
  }
}

# vim:sw=2:ts=2:expandtab:textwidth=79
