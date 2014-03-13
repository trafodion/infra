#
# Defined resource type to configure jenkins authorized users
#

define jenkins::add_pub_key ($pub_key) {
    #notify { "add_pub_key: name is $name": }
    #notify { "add_pub_key: Name $name has key : $pub_key": }
    ssh_authorized_key { "$name":
      ensure  => present,
      key     => "$pub_key",
      user    => 'jenkins',
      type    => 'ssh-rsa',
      require => File['/home/jenkins/.ssh'],
  }
}
