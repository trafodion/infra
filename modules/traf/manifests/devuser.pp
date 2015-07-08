# == define (resource type) traf::devuser
# realize user list from hiera data
define traf::devuser(
  $groups = [],
) {

  # user accounts
  $userrh = hiera('user_real')
  $username = $userrh[$name]
  $userkh  = hiera('user_key')
  $userkey = $userkh[$name]

  user::virtual::localuser { $title :
    groups   => $groups,
    realname => "$username",
    sshkeys  => "$userkey",
  }

  file { "/mnt/$title" :
    ensure  => directory,
    owner   => "$title",
    group   => "$title",
    mode    => '0755',
    require => User::Virtual::Localuser[$title],
  }

}
