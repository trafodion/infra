# == Class: traf::python276
#
class traf::python276 {

  # Gets Python 2.7.6 (last 2.7.x) source files
  # so we can compile and set up a version that 
  # supports UCS2

  $python_file = 'Python-2.7.6.tgz'

  file { '/var/python276':
    ensure => directory,
  }

  file { '/var/python276/Python-2.7.6.md5.orig':
      mode    => '0644',
      source  => 'puppet:///modules/traf/python/Python-2.7.6.md5',
      require => File['/var/python276'],
  }

  exec { 'download_Python2.7.6':
      path    => '/usr/bin:/bin:/usr/local/bin',
      cwd     => '/var/python276',
      command => "wget -O - http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tgz | tee ${python_file} | md5sum > Python-2.7.6.md5.download; diff -wq Python-2.7.6.md5.download Python-2.7.6.md5.orig",
      creates => "/var/python276/${python_file}",
      require => File['/var/python276/Python-2.7.6.md5.orig'],
      unless  => "test `/usr/local/bin/python --version 2>&1 | egrep -c 'Python 2.7.6'` -eq 1 && test `/usr/local/bin/python -c 'import sys; print sys.maxunicode;'` = '65535'",
  }

  exec { 'untar_Python2.7.6':
      path        => '/usr/bin:/bin:/usr/local/bin',
      cwd         => '/var/python276',
      command     => "tar xfz ${python_file}",
      creates     => '/var/python276/Python-2.7.6/configure',
      refreshonly => true,
      subscribe   => Exec['download_Python2.7.6'],
  }

  exec { 'configure_Python2.7.6':
      path        => '/usr/bin:/bin:/usr/local/bin:/var/python276/Python-2.7.6',
      cwd         => '/var/python276/Python-2.7.6',
      command     => './configure --enable-unicode=ucs2 --prefix=/usr/local',
      creates     => '/var/python276/Python-2.7.6/Makefile',
      refreshonly => true,
      require     => Package['libpcap-devel'],
      subscribe   => Exec['untar_Python2.7.6'],
  }

  exec { 'make_Python2.7.6':
      path        => '/usr/bin:/bin:/usr/local/bin:/var/python276/Python-2.7.6',
      cwd         => '/var/python276/Python-2.7.6',
      command     => 'make',
      timeout     => '600',
      creates     => '/var/python276/Python-2.7.6/build/lib.linux-x86_64-2.7/_ctypes.so',
      refreshonly => true,
      subscribe   => Exec['configure_Python2.7.6'],
  }

  exec { 'make_install_Python2.7.6':
      path        => '/usr/bin:/bin:/usr/local/bin:/var/python276/Python-2.7.6',
      cwd         => '/var/python276/Python-2.7.6',
      command     => 'make altinstall',
      timeout     => '300',
      creates     => '/usr/local/bin/python2.7',
      refreshonly => true,
      subscribe   => Exec['make_Python2.7.6'],
  }

  exec { 'link_Python2.7.6':
      path        => '/usr/bin:/bin:/usr/local/bin',
      cwd         => '/usr/local/bin',
      command     => 'ln -s python2.7 python',
      creates     => '/usr/local/bin/python',
      refreshonly => true,
      subscribe   => Exec['make_install_Python2.7.6'],
  }

  # Download and install pip for Python 2.7
  # NOTE: This should also install setuptools
  exec { 'download_python_pip':
      path    => '/usr/local/bin:/usr/bin:/bin',
      cwd     => '/var/python276',
      command => 'wget --no-check-certificate https://raw.github.com/pypa/pip/master/contrib/get-pip.py',
      creates => '/var/python276/get-pip.py',
      require => File['/var/python276'],
  }

  # NOTE: Make sure the path to the newly compiled python binary comes first!
  exec { 'run_get-pip.py':
      path        => '/usr/local/bin:/usr/bin:/bin',
      cwd         => '/var/python276',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'python get-pip.py',
      creates     => '/usr/local/bin/pip',
      require     => [ Exec['download_python_pip'], Exec['link_Python2.7.6'] ],
  }

  # install other python packages via pip
  exec { 'pip_install_virtualenv' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install virtualenv==1.11.6',
      unless      => "pip freeze | grep 'virtualenv==1.11.6'",
      creates     => '/usr/local/bin/virtualenv',
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_flake8' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install flake8==2.0',
      creates     => '/usr/local/bin/flake8',
      unless      => "pip freeze | grep 'flake8==2.0'",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_pyflakes' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install pyflakes',
      creates     => '/usr/local/bin/pyflakes',
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_python-subunit' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install python-subunit==0.0.21',
      creates     => '/usr/local/bin/subunit2pyunit',
      unless      => "pip freeze | grep 'python-subunit==0.0.21'",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_testrepository' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install testrepository==0.0.20',
      creates     => '/usr/local/bin/testr',
      unless      => "pip freeze | grep 'testrepository==0.0.20'",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_junitxml' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install junitxml',
      creates     => '/usr/local/bin/pyjunitxml',
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_pep8' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install pep8==1.4.5',
      creates     => '/usr/local/bin/pep8',
      unless      => "pip freeze | grep 'pep8==1.4.5'",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_tox' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install tox==1.7.2',
      creates     => '/usr/local/bin/tox',
      unless      => "pip freeze | grep 'tox==1.7.2'",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_pythonodbc' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install http://dl.bintray.com/alchen99/python/pyodbc-3.0.7.1-unsupported.zip',
      unless      => "pip freeze | grep 'pyodbc==3.0.7.1-unsupported'",
      require     => Exec['run_get-pip.py'],
  }

  exec { 'pip_install_pypyodbc' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip install http://dl.bintray.com/alchen99/python/pypyodbc-1.3.3.1-unsupported.zip',
      unless      => "pip freeze | grep 'pypyodbc==1.3.3.1-unsupported'",
      require     => Exec['run_get-pip.py'],
  }

  # make sure pep8 and tox are the correct versions
  exec { 'check_pep8_version' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip uninstall -y pep8; pip install pep8==1.4.5',
      unless      => "pip freeze | grep 'pep8==1.4.5'",
      require     => [
        Exec['pip_install_virtualenv'], Exec['pip_install_flake8'],
        Exec['pip_install_pyflakes'], Exec['pip_install_python-subunit'],
        Exec['pip_install_testrepository'], Exec['pip_install_pep8'],
        Exec['pip_install_tox'], Exec['pip_install_junitxml'],
        Exec['pip_install_pythonodbc'], Exec['pip_install_pypyodbc'],
      ],
  }

  exec { 'check_tox_version' :
      path        => '/usr/local/bin:/usr/bin:/bin',
      environment => 'PYTHONHOME=/usr/local',
      command     => 'pip uninstall -y tox; pip install tox==1.7.2',
      unless      => "pip freeze | grep 'tox==1.7.2'",
      require     => [
        Exec['pip_install_virtualenv'], Exec['pip_install_flake8'],
        Exec['pip_install_pyflakes'], Exec['pip_install_python-subunit'],
        Exec['pip_install_testrepository'], Exec['pip_install_pep8'],
        Exec['pip_install_tox'], Exec['pip_install_junitxml'],
        Exec['pip_install_pythonodbc'], Exec['pip_install_pypyodbc'],
      ],
  }

}
