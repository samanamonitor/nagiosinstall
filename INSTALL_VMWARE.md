# install vmware sdk in SAMM
ln -s /bin/true /sbin/lsmod
ln -s /bin/true /sbin/depmod
TEMPDIR=$(mktemp -d)
apt install -y  libxml-libxml-perl libxml2-dev xml2 uuid-dev perl-doc rpm libsoap-lite-perl libssl-dev libcrypt-ssleay-perl libdevel-stacktrace-perl libclass-data-inheritable-perl libconvert-asn1-perl libcrypt-openssl-rsa-perl libcrypt-x509-perl libexception-class-perl libarchive-zip-perl libpath-class-perl libclass-methodmaker-perl libsocket6-perl libio-socket-inet6-perl libnet-inet6glue-perl 
cpan install BINGOS/ExtUtils-MakeMaker-6.96.tar.gz
cpan install LEONT/Module-Build-0.4205.tar.gz
cpan install GBARR/libnet-1.22.tar.gz
cpan install GAAS/LWP-Protocol-https-6.04.tar.gz

libmodule-build-perl
libextutils-makemaker-cpanfile-perl
cd ${TEMPDIR}
tar -xzvf /usr/src/VMware-vSphere-Perl-SDK-6.5.0-4566394.x86_64.tar.gz