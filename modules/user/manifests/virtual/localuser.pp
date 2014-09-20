# usage
#
# user::virtual::localuser['username']
#  sshkeys can be a public key string or 'generate' to generate a key
#  generating a key provides only local-host ssh access

define user::virtual::localuser(
  $realname,
  $groups     = [ 'sudo', 'admin', ],
  $sshkeys    = '',
  $shell      = '/bin/bash',
  $home       = "/home/${title}",
  $managehome = true
) {
  group { $title:
    ensure => present,
  }

  user { $title:
    ensure     => present,
    comment    => $realname,
    gid        => $title,
    groups     => $groups,
    home       => $home,
    managehome => $managehome,
    membership => 'minimum',
    require    => Group[$title],
    shell      => $shell,
  }

  file { "${title}_sshdir":
    ensure  => directory,
    name    => "${home}/.ssh",
    owner   => $title,
    group   => $title,
    mode    => '0700',
    require => User[$title],
  }

  if $sshkeys == 'generate' {
    exec { 'ssh_local':
      command => "/usr/bin/ssh-keygen -t rsa -N '' -f ${home}/.ssh/id_rsa",
      user    => $title,
      creates => "${home}/.ssh/id_rsa",
      require => File["${title}_sshdir"],
    }
    file { "${title}_keys":
      ensure  => present,
      source => '${home}/.ssh/id_rsa.pub',
      group   => $title,
      mode    => '0400',
      name    => "${home}/.ssh/authorized_keys",
      owner   => $title,
      require => Exec['ssh_local'],
    }
  }
  else {
    file { "${title}_keys":
      ensure  => present,
      content => $sshkeys,
      group   => $title,
      mode    => '0400',
      name    => "${home}/.ssh/authorized_keys",
      owner   => $title,
      require => File["${title}_sshdir"],
    }
  }
}

# vim:sw=2:ts=2:expandtab:textwidth=79
