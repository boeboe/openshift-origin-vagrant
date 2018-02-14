#!/usr/bin/env bash
#
# Small helper script to quickly generate new centos/7 based VBoxGuestAdditions enabled boxes
#

GREEN='\033[1;32m'
BLUE='\033[0;34m'
RED='\033[1;31m'
NC='\033[0m'

VAGRANT_BIN='vagrant'
VAGRANT_EXEC="${VAGRANT_BIN} ssh -c "
VB_URL='http://download.virtualbox.org/virtualbox'
VB_VERSION='not_set'

function check_vb_version() {
    echo -e "${GREEN}Check if version $1 is avaiable for VirtualBox${NC}"

    if ! curl -f "${VB_URL}/$1" &>/dev/null; then 
         echo -e "${RED}VirtualBox version $1 does not exist ${NC}"
         exit 1
    fi
}

function wait_for_box() {
    echo -e "${GREEN}Waiting for vagrant box to become ready ${NC}"
    while ${VAGRANT_BIN} status | grep running | grep 1/1 &>/dev/null; do
        echo -n "."
        sleep 1
    done
    echo 
}

if [ -z "$1" ]; then
    echo 'Usage: create-box.sh <virtualbox-version>'
    echo '    <virtualbox-version> : example 5.2.6'
    exit 0
else
    export VB_VERSION=$1
    check_vb_version ${VB_VERSION}
    echo -e "${GREEN}Going to create a new centos/7 box with VBoxGuestAdditions version ${VB_VERSION}${NC}"
fi


${VAGRANT_BIN} destroy -f
rm -rf ./.vagrant

echo -e "${GREEN}Starting up vagrant box${NC}"
${VAGRANT_BIN} up

wait_for_box

echo -e "${GREEN}Updating kernel and other packages${NC}"
${VAGRANT_EXEC} "sudo yum -y update"
echo -e "${GREEN}Installing prerequisites for VBoxGuestAdditions${NC}"
${VAGRANT_EXEC} "sudo yum -y install dkms gcc make kernel-devel bzip2 binutils patch libgomp glibc-headers glibc-devel \
                    kernel-headers"
${VAGRANT_EXEC} "sudo init 6"

sleep 2
wait_for_box

echo -e "${GREEN}Installing VBoxGuestAdditions version ${VB_VERSION}${NC}"
${VAGRANT_EXEC} "curl ${VB_URL}/${VB_VERSION}/VBoxGuestAdditions_${VB_VERSION}.iso  -o /tmp/VBoxGuestAdditions_${VB_VERSION}.iso"
${VAGRANT_EXEC} "sudo mount /tmp/VBoxGuestAdditions_${VB_VERSION}.iso -o loop /mnt"
${VAGRANT_EXEC} "sudo sh /mnt/VBoxLinuxAdditions.run --nox11"

echo -e "${GREEN}Clean-up to slim down box size${NC}"
${VAGRANT_EXEC} "sudo umount /mnt"
${VAGRANT_EXEC} "sudo rm /tmp/*.iso"
${VAGRANT_EXEC} "sudo yum remove -y gcc glibc-devel glibc-headers kernel-devel kernel-headers patch cpp libmpc mpfr perl \
                    perl-Carp perl-Encode perl-Exporter  perl-File-Path perl-File-Temp perl-Filter perl-Getopt-Long \
                    perl-HTTP-Tiny perl-PathTools perl-Pod-Escapes perl-Pod-Perldoc perl-Pod-Simple perl-Pod-Usage \
                    perl-Scalar-List-Utils perl-Socket perl-Storable perl-Text-ParseWords perl-Time-HiRes perl-Time-Local \
                    perl-constant perl-libs perl-macros perl-parent perl-podlators perl-threads perl-threads-shared"
${VAGRANT_EXEC} "sudo yum clean all"
${VAGRANT_EXEC} "sudo rm -rf /var/cache/yum"

echo -e "${GREEN}Fill hard disk with zero's for better compression ratio${NC}"
${VAGRANT_EXEC} "sudo dd if=/dev/zero of=/EMPTY bs=1M"
${VAGRANT_EXEC} "sudo rm -f /EMPTY"
${VAGRANT_EXEC} "cat /dev/null > ~/.bash_history && history -c && exit"

echo -e "${GREEN}Packaging resulting VM as a new box${NC}"
${VAGRANT_BIN} package --output output/centos7-vbguest-${VB_VERSION}.box
ls -la output/
echo -e "${GREEN}Successfully created a new box: output/centos7-vbguest-${VB_VERSION}.box${NC}"
