#!/bin/sh

# arrdvark installation script 


# CHANGE LOG
# ----------
# 2017/02/15	njeffrey	Script created



# OUTSTANDING TASKS
# -----------------
# - prompt user to select a UID for the arrdvark user
# - check to see if crontab entry already exists before adding new cron entry
# - check the current directory to ensure we are not installing from the destination directory
# - confirm all required files are available
# - give the user a way to change the port the webserver listens on 



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



# create a cron entries for arrdvark user
if [ ! -f /var/spool/cron/crontabs/arrdvark ]; then
   echo Creating crontabl file /var/spool/cron/crontabs/arrdvark
   touch /var/spool/cron/crontabs/arrdvark
   chown arrdvark:cron /var/spool/cron/crontabs/arrdvark
fi
if [ -f /var/spool/cron/crontabs/arrdvark ]; then
   grep arrdvark.pl /var/spool/cron/crontabs/arrdvark || ( 
      echo '0,5,10,15,20,25,30,35,40,45,50,55 * * * * /home/arrdvark/arrdvark.pl >/dev/null 2>&1  #generate RRD perf metrics' >> /var/spool/cron/crontabs/arrdvark
   )
   grep dashboard.pl /var/spool/cron/crontabs/arrdvark || ( 
      echo '1,16,31,46 * * * * /home/arrdvark/dashboard.pl >/dev/null 2>&1  #generate health report' >> /var/spool/cron/crontabs/arrdvark
   )
   grep sysinfo.pl /var/spool/cron/crontabs/arrdvark || ( 
      echo '55 23 * * * /home/arrdvark/sysinfo.pl >/dev/null 2>&1  #generate daily inventory report' >> /var/spool/cron/crontabs/arrdvark
   )
fi




# copy files
cp arrdvark.pl  /home/arrdvark/arrdvark.pl
cp dashboard.pl /home/arrdvark/dashboard.pl
cp sysinfo.pl   /home/arrdvark/sysinfo.pl
cp httpd.pl     /home/arrdvark/httpd.pl


# set file permissions
chown arrdvark:staff /home/arrdvark/*.pl
chmod 755            /home/arrdvark/*.pl



# start tiny self-contained perl web server
netstat -an | grep 8081 || (
   echo Starting self-contained perl webserver on port 8081
   nohup /home/arrdvark/httpd.pl 8081 &
)

# ensure the webserver will start at the next boot
test -f /etc/rc.local || touch /etc/rc.local
grep "/home/arrdvark/httpd.pl" /etc/rc.local || (
   echo '#start webserver for arrdvark'
   echo 'su - arrdvark -c "/home/arrdvark/httpd.pl 8081 &"' >> /etc/rc.local
)
