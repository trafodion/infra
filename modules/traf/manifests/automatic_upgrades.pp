# == Class: traf::automatic_upgrades
#
class traf::automatic_upgrades (
  $origins = []
) {

  if $::osfamily == 'Debian' {
    class { 'unattended_upgrades':
      origins => $origins,
    }

  }
  if $::osfamily == 'RedHat' {
    include packagekit::cron
  }

}
