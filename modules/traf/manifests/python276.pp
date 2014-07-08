# == Class: traf::python276
#
class traf::python276 {

  # Gets Python 2.7.6 (last 2.7.x) source files
  # so we can compile and set up a version that 
  # supports UCS2

  $python_file = 'Python-2.7.6.tgz'

  file { '/tmp/python':
    ensure => directory,
  }

  file { '/tmp/python/Python-2.7.6.md5.orig':
      mode   => '0644',
      source => "puppet:///modules/traf/python/Python-2.7.6.md5",
      require => File['/tmp/python'],
  }

  exec { 'download_Python2.7.6':
      path    => "/usr/bin:/bin:/usr/local/bin",
      cwd     => "/tmp/python",
      command => "wget -O - http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tgz | tee $python_file | md5sum > Python-2.7.6.md5.download; diff -wq Python-2.7.6.md5.download Python-2.7.6.md5.orig",
      creates => "/tmp/python/$python_file",
      require => File['/tmp/python/Python-2.7.6.md5.orig'],
  }

  exec { 'untar_Python2.7.6':
      path    => "/usr/bin:/bin:/usr/local/bin",
      cwd     => "/tmp/python",
      command => "tar xfz $python_file",
      creates => "/tmp/python/Python-2.7.6/configure",
      require => Exec['download_Python2.7.6'],
  }

  exec { 'configure_Python2.7.6':
      path    => "/usr/bin:/bin:/usr/local/bin:/tmp/python/Python-2.7.6",
      cwd     => "/tmp/python/Python-2.7.6",
      command => "./configure --enable-unicode=ucs2 --prefix=/usr/local",
      creates => "/tmp/python/Python-2.7.6/Makefile",
      require => [ Exec['untar_Python2.7.6'], Package['libpcap-devel'] ]
  }

  exec { 'make_Python2.7.6':
      path    => "/usr/bin:/bin:/usr/local/bin:/tmp/python/Python-2.7.6",
      cwd     => "/tmp/python/Python-2.7.6",
      command => "make",
      timeout => '600',
      creates => "/tmp/python/Python-2.7.6/build/lib.linux-x86_64-2.7/_ctypes.so",
      require => Exec['configure_Python2.7.6'],
  }

  exec { 'make_install_Python2.7.6':
      path    => "/usr/bin:/bin:/usr/local/bin:/tmp/python/Python-2.7.6",
      cwd     => "/tmp/python/Python-2.7.6",
      command => "make altinstall",
      timeout => '300',
      creates => "/usr/local/bin/python2.7",
      require => Exec['make_Python2.7.6'],
  }

  exec { 'link_Python2.7.6':
      path    => "/usr/bin:/bin:/usr/local/bin",
      cwd     => "/usr/local/bin",
      command => "ln -s python2.7 python",
      creates => "/usr/local/bin/python",
      require => Exec['make_install_Python2.7.6'],
  }

  # Download and install pip for Python 2.7
  # NOTE: This should also install setuptools
  exec { 'download_python_pip':
      path    => "/usr/local/bin:/usr/bin:/bin",
      cwd     => "/tmp/python",
      command => "wget --no-check-certificate https://raw.github.com/pypa/pip/master/contrib/get-pip.py",
      creates => "/tmp/python/get-pip.py",
      require => File['/tmp/python'],
  }

  # NOTE: Make sure the path to the newly compiled python binary comes first!
  exec { 'run_get-pip.py':
      path        => "/usr/local/bin:/usr/bin:/bin",
      cwd         => "/tmp/python",
      environment => "PYTHONHOME=/usr/local",
      command     => "python get-pip.py",
      creates     => "/usr/local/bin/pip",
      require     => [ Exec['download_python_pip'], Exec['link_Python2.7.6'] ],
  }

  # install other python packages via pip
  exec { 'pip_install_virtualenv' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip install virtualenv",
      creates     => "/usr/local/bin/virtualenv",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_flake8' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip install flake8==2.0",
      creates     => "/usr/local/bin/flake8",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_pyflakes' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip install pyflakes",
      creates     => "/usr/local/bin/pyflakes",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_python-subunit' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip install python-subunit",
      creates     => "/usr/local/bin/subunit2pyunit",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_testrepository' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip install testrepository",
      creates     => "/usr/local/bin/testr",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_junitxml' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip install junitxml",
      creates     => "/usr/local/bin/pyjunitxml",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_pep8' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip install pep8==1.4.5",
      creates     => "/usr/local/bin/pep8",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_tox' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip install tox==1.6.1",
      creates     => "/usr/local/bin/tox",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_pythonodbc' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip install http://dl.bintray.com/alchen99/python/pyodbc-3.0.7.1-unsupported.zip",
      unless      => "pip freeze | grep 'pyodbc==3.0.7.1-unsupported'",
      require     => Exec['run_get-pip.py'],
  }

  # make sure pep8 and tox are the correct versions
  exec { 'check_pep8_version' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip uninstall -y pep8; pip install pep8==1.4.5",
      unless      => "pip freeze | grep 'pep8==1.4.5'",
      require     => [ Exec['pip_install_virtualenv'], Exec['pip_install_flake8'], 
                       Exec['pip_install_pyflakes'], Exec['pip_install_python-subunit'], 
                       Exec['pip_install_testrepository'], Exec['pip_install_pep8'],
                       Exec['pip_install_tox'], Exec['pip_install_junitxml'],
                       Exec['pip_install_pythonodbc'] ],
  }

  exec { 'check_tox_version' :
      path        => "/usr/local/bin:/usr/bin:/bin",
      environment => "PYTHONHOME=/usr/local",
      command     => "pip uninstall -y tox; pip install tox==1.6.1",
      unless      => "pip freeze | grep 'tox==1.6.1'",
      require     => [ Exec['pip_install_virtualenv'], Exec['pip_install_flake8'], 
                       Exec['pip_install_pyflakes'], Exec['pip_install_python-subunit'], 
                       Exec['pip_install_testrepository'], Exec['pip_install_pep8'],
                       Exec['pip_install_tox'], Exec['pip_install_junitxml'],
                       Exec['pip_install_pythonodbc'] ],
  }

  # copy missing file subunit2csv to /usr/local/bin
  file { '/usr/local/bin/subunit2csv':
      ensure => present,
      mode   => '0775',
      source => "puppet:///modules/traf/python/subunit2csv",
  }

}
