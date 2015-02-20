#
# This class holds parameters that need to be
# accessed by other classes.
class traf::params {
  case $::osfamily {
    'RedHat': {
      $packages = ['puppet', 'python-setuptools', 'wget', 'openssl-devel']
      $non_slave_packages = ['libffi-devel']
      $user_packages = ['byobu', 'emacs-nox']
      $update_pkg_list_cmd = ''
    }
    'Debian': {
      $packages = ['puppet', 'python-setuptools', 'wget', 'libssl-dev']
      $non_slave_packages = ['libffi-dev']
      $user_packages = ['byobu', 'emacs23-nox']
      $update_pkg_list_cmd = 'apt-get update >/dev/null 2>&1;'
    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} The 'traf' module only supports osfamily Debian or RedHat (slaves only).")
    }
  }
}
