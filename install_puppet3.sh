#!/bin/bash

# Copyright 2013 OpenStack Foundation.
# Copyright 2013 Hewlett-Packard Development Company, L.P.
# Copyright 2013 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.


#
# Distro identification functions
#  note, can't rely on lsb_release for these as we're bare-bones and
#  it may not be installed yet)


function is_fedora {
    [ -f /usr/bin/yum ] && cat /etc/*release | grep -q -e "Fedora"
}

function is_rhel6 {
    [ -f /usr/bin/yum ] && \
        cat /etc/*release | grep -q -e "Red Hat" -e "CentOS" && \
        cat /etc/*release | grep -q 'release 6'
}

function is_rhel7 {
    [ -f /usr/bin/yum ] && \
        cat /etc/*release | grep -q -e "Red Hat" -e "CentOS" && \
        cat /etc/*release | grep -q 'release 7'
}

function is_ubuntu {
    [ -f /usr/bin/apt-get ]
}

function is_opensuse {
    [ -f /usr/bin/zypper ] && \
        cat /etc/os-release | grep -q -e "openSUSE"
}

#
# Distro specific puppet installs
#

function setup_puppet_fedora {
    yum update -y

    # NOTE: we preinstall lsb_release to ensure facter sets
    # lsbdistcodename
    yum install -y redhat-lsb-core git puppet


    mkdir -p /etc/puppet/modules/

    # Puppet expects the pip command named as pip-python on
    # Fedora, as per the packaged command name.  However, we're
    # installing from get-pip.py so it's just 'pip'.  An easy
    # work-around is to just symlink pip-python to "fool" it.
    # See upstream issue:
    #  https://tickets.puppetlabs.com/browse/PUP-1082
    ln -fs /usr/bin/pip /usr/bin/pip-python
}

function setup_puppet_rhel7 {

    local puppet_pkg="https://yum.puppetlabs.com/el/7/products/x86_64/puppetlabs-release-7-10.noarch.rpm"

    # install a bootstrap epel repo to install latest epel-release
    # package (which provides correct gpg keys, etc); then remove
    # boostrap
    cat > /etc/yum.repos.d/epel-bootstrap.repo <<EOF
[epel-bootstrap]
name=Bootstrap EPEL
mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=epel-7&arch=\$basearch
failovermethod=priority
enabled=0
gpgcheck=0
EOF
    yum --enablerepo=epel-bootstrap -y install epel-release
    rm -f /etc/yum.repos.d/epel-bootstrap.repo

    # NOTE: we preinstall lsb_release to ensure facter sets lsbdistcodename
    yum install -y redhat-lsb-core git puppet

    rpm -ivh $puppet_pkg

    # see comments in setup_puppet_fedora
    ln -s /usr/bin/pip /usr/bin/pip-python
}

function setup_puppet_rhel6 {
    local puppet_pkg="http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-6.noarch.rpm"

    # install a bootstrap epel repo to install latest epel-release
    # package (which provides correct gpg keys, etc); then remove
    # boostrap
    cat > /etc/yum.repos.d/epel-bootstrap.repo <<EOF
[epel-bootstrap]
name=Bootstrap EPEL
mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=epel-6&arch=\$basearch
failovermethod=priority
enabled=0
gpgcheck=0
EOF
    yum --enablerepo=epel-bootstrap -y install epel-release
    rm -f /etc/yum.repos.d/epel-bootstrap.repo

    # NOTE: we preinstall lsb_release to ensure facter sets lsbdistcodename
    yum install -y redhat-lsb-core git puppet

    rpm -ivh $puppet_pkg

    # ensure we stick to supported puppet 2 versions
    cat > /etc/yum.repos.d/puppetlabs.repo <<"EOF"
[puppetlabs-products]
name=Puppet Labs Products El 6 - $basearch
baseurl=http://yum.puppetlabs.com/el/6/products/$basearch
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs
enabled=1
gpgcheck=1
exclude=puppet-4* facter-3* puppetserver-2*
EOF

    yum update -y

    # see comments in setup_puppet_fedora
    ln -s /usr/bin/pip /usr/bin/pip-python
}

function setup_puppet_ubuntu {
    if ! which lsb_release > /dev/null 2<&1 ; then
        DEBIAN_FRONTEND=noninteractive apt-get --option 'Dpkg::Options::=--force-confold' \
            --assume-yes install -y --force-yes lsb-release
    fi

    lsbdistcodename=`lsb_release -c -s`
    if [ $lsbdistcodename != 'trusty' ] ; then
        rubypkg=rubygems
    else
        rubypkg=ruby
    fi


    PUPPET_VERSION=3.*
    PUPPETDB_VERSION=2.*
    PUPSERVER_VERSION=1.*
    FACTER_VERSION=2.*

    cat > /etc/apt/preferences.d/00-puppet.pref <<EOF
Package: puppet puppet-common puppetmaster puppetmaster-common puppetmaster-passenger
Pin: version $PUPPET_VERSION
Pin-Priority: 501

Package: puppetdb puppetdb-terminus
Pin: version $PUPPETDB_VERSION
Pin-Priority: 501

Package: puppetserver
Pin: version $PUPSERVER_VERSION
Pin-Priority: 501

Package: facter
Pin: version $FACTER_VERSION
Pin-Priority: 501
EOF

    puppet_deb=puppetlabs-release-${lsbdistcodename}.deb
    wget http://apt.puppetlabs.com/$puppet_deb -O $puppet_deb
    dpkg -i $puppet_deb
    rm $puppet_deb

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get --option 'Dpkg::Options::=--force-confold' \
        --assume-yes dist-upgrade
    DEBIAN_FRONTEND=noninteractive apt-get --option 'Dpkg::Options::=--force-confold' \
        --assume-yes install -y --force-yes puppet git $rubypkg
}

function setup_puppet_opensuse {
    local version=`grep -e "VERSION_ID" /etc/os-release | tr -d "\"" | cut -d "=" -f2`
    zypper ar http://download.opensuse.org/repositories/systemsmanagement:/puppet/openSUSE_${version}/systemsmanagement:puppet.repo
    zypper -v --gpg-auto-import-keys --no-gpg-checks -n ref
    zypper --non-interactive in --force-resolution puppet
}

#
# pip setup
#

function setup_pip {
    # Install pip

    if is_opensuse; then
        zypper --non-interactive in --force-resolution python python-xml
    fi

    # python-setuptools includes easy_install module
    yum install -y python-setuptools

    # must specify python version, since multiple versions may be installed
    # This should be the /usr/bin (system) version of python
    /usr/bin/python -m easy_install -U pip 
    /usr/bin/pip install -y -U setuptools
}

setup_pip

if is_fedora; then
    setup_puppet_fedora
elif is_rhel6; then
    setup_puppet_rhel6
elif is_rhel7; then
    setup_puppet_rhel7
elif is_ubuntu; then
    setup_puppet_ubuntu
elif is_opensuse; then
    setup_puppet_opensuse
else
    echo "*** Can not setup puppet: distribution not recognized"
    exit 1
fi
