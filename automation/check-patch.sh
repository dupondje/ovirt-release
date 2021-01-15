#!/bin/bash -xe

./automation/build-artifacts.sh

DISTVER="$(rpm --eval "%dist"|cut -c2-4)"
ARCH="$(rpm --eval "%_arch")"
PACKAGER=dnf
export PACKAGER

on_exit() {
    ${PACKAGER} --verbose clean all
}

trap on_exit EXIT



find \
    "$PWD/tmp.repos" \
    -iname \*.rpm \
    -exec mv {} exported-artifacts/ \;
pushd exported-artifacts
    #Restoring sane yum environment
    rm -f /etc/yum.conf
    ${PACKAGER} reinstall -y system-release ${PACKAGER}
    [[ -d /etc/dnf ]] && [[ -x /usr/bin/dnf ]] && dnf -y reinstall dnf-conf
    [[ -d /etc/dnf ]] && sed -i -re 's#^(reposdir *= *).*$#\1/etc/yum.repos.d#' '/etc/dnf/dnf.conf'
    [[ -e /etc/dnf/dnf.conf ]] && echo "deltarpm=False" >> /etc/dnf/dnf.conf
    ${PACKAGER} install -y ovirt-release-master-4*noarch.rpm
    rm -f /etc/yum/yum.conf
    ${PACKAGER} repolist enabled
    ${PACKAGER} clean all
    if [[ "${ARCH}" == "s390x" ]]; then
        # s390x support is broken, just provide a hint on what's missing
        # without causing the test to fail.
        ${PACKAGER} --downloadonly install *noarch.rpm || true
    elif
     [[ "$(rpm --eval "%dist")" == ".el8" ]]; then
        ${PACKAGER} --downloadonly install *noarch.rpm
        if [[ "${ARCH}" == "x86_64" ]]; then
            ${PACKAGER} --downloadonly install ovirt-engine ovirt-engine-setup-plugin-websocket-proxy
        fi
        echo "Testing CentOS Stream"
        ${PACKAGER} remove ovirt-release-master
        ${PACKAGER} install -y centos-release-stream
        ${PACKAGER} repolist enabled
        ${PACKAGER} --releasever=8-stream --disablerepo=* --enablerepo=Stream-BaseOS download centos-stream-repos
        ${PACKAGER} install -y centos-stream-release
        rpm -e --nodeps centos-linux-repos
        rpm -i centos-stream-repo*
        rm -fv centos-stream-repo*
        ls -l /etc/yum.repos.d/
        ${PACKAGER} distro-sync -y
        ${PACKAGER} install -y ovirt-release-master-4*noarch.rpm
        ${PACKAGER} repolist enabled
        ${PACKAGER} clean all
        ${PACKAGER} --downloadonly install *noarch.rpm || true
        if [[ "${ARCH}" == "x86_64" ]]; then
            ${PACKAGER} --downloadonly install ovirt-engine ovirt-engine-setup-plugin-websocket-proxy || true
        fi
    else
        if [[ $(${PACKAGER} repolist enabled|grep -v ovirt|grep epel) ]] ; then
            ${PACKAGER} --downloadonly --disablerepo=epel install *noarch.rpm
            if [[ "${ARCH}" == "x86_64" ]]; then
                ${PACKAGER} --downloadonly --disablerepo=epel install ovirt-engine ovirt-engine-setup-plugin-websocket-proxy
            fi
        else
            ${PACKAGER} --downloadonly install *noarch.rpm
            if [[ "${ARCH}" == "x86_64" ]]; then
                ${PACKAGER} --downloadonly install ovirt-engine ovirt-engine-setup-plugin-websocket-proxy
            fi
        fi
    fi
popd
