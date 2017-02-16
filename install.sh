#!/bin/sh

# arrdvark installation script 


# CHANGE LOG
# ----------
# 2017/02/15	njeffrey	Script created



# OUTSTANDING TASKS
# -----------------
# - prompt user to select a UID for the arrdvark user
# - check to see if crontab entry already exists before adding new cron entry




# confirm current user is root (required to create arrdvark userid)
if [ "$(/usr/bin/id -u)" -ne "0" ] ; then
    echo "This script must be executed with root privileges."
    exit 1
fi



# confirm current host is running AIX
/usr/bin/uname | grep AIX || (
   echo ERROR: this script only runs on AIX
   exit
)



# create arrdvark user
/usr/sbin/lsuser arrdvark | grep arrdvark && echo arrkvark user already exists
/usr/sbin/lsuser arrdvark | grep arrdvark || (
   echo Creating arrkvark user 
   /usr/bin/mkuser arrdvark
)


# install RRD::Editor perl module
if [ ! -f /usr/opt/perl5/lib/site_perl/5.10.1/RRD/Editor.pm ]; then 
   echo installing RRD::Editor perl module to /usr/opt/perl5/lib/site_perl/5.10.1/RRD/Editor.pm
   if [ -d /usr/opt/perl5/lib/site_perl/5.10.1 ]; then
      test -d /usr/opt/perl5/lib/site_perl/5.10.1/RRD || mkdir /usr/opt/perl5/lib/site_perl/5.10.1/RRD
      test -f /usr/opt/perl5/lib/site_perl/5.10.1/RRD/Editor.pm || cp Editor.pm /usr/opt/perl5/lib/site_perl/5.10.1/RRD/Editor.pm
   fi
fi



# create a cron entry for arrdvark user
if [ ! -f /var/spool/cron/crontabs/arrdvark ]; then
   echo Creating crontabl file /var/spool/cron/crontabs/arrdvark
   touch /var/spool/cron/crontabs/arrdvark
   chown arrdvark:cron /var/spool/cron/crontabs/arrdvark
fi
if [ -f /var/spool/cron/crontabs/arrdvark ]; then
   grep arrdvark.pl /var/spool/cron/crontabs/arrdvark || echo '0,5,10,15,20,25,30,35,40,45,50,55 * * * * /home/arrdvark/arrdvark.pl >/dev/null 2>&1  #generate RRD performance metrics' >> /var/spool/cron/crontabs/arrdvark
fi



