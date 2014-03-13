# == Class: traf::tmpcleanup
#
class traf::tmpcleanup (
) {

  if $::osfamily == 'Debian' {
    include tmpreaper
  }

  # FIXME need to implement an something on RHEL to fine tune the
  # temp directory cleanup.

}
