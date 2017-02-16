#!/usr/bin/perl

# OUTSTANDING TASKS
# -----------------
# nslookup against all name servers
# confirm all filesystems mounted
# confirm telnet is disabled
# check volume groups (stale PP, all readable, blv, mirrored, etc)
# Confirm all disks in rootvg have a boot logical volume
# look for accounts with multiple bad password attempts
# check to see if there is a lot of paging activity
# disk space does not show up in red if nearly full

# script to build a web-based dashboard for the local AIX machine showing basic health stats

# NOTES 
# ------
#  It is assumed that this script is run hourly from a cron job.  Example:
#  9 * * * * /home/arrdvark/dashboard.pl > /home/arrdvark/html/dashboard.html 2>/dev/null #generate report on system health


use strict;							#enforce good coding practices
use warnings; 							#tell perl interpreter to provide verbose warnings


# declare variables
my ($df,$ps,$lslpp,$netstat,$hostname,$oslevel,$errpt,$sysdumpdev,$ping,$nfso,$lsvg,$lsfs,$lsps,$ntpq,$mount,$uname,$iostat);
my ($verbose,%checks,%filesystems,$cmd,$key);
my ($date,$epoch,$bgcolor,$filename);
my ($device,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks);  #variables used by perl stat
$df         = "/usr/bin/df";               			#location of binary
$ps         = "/usr/bin/ps";               			#location of binary
$lslpp      = "/usr/bin/lslpp";        				#location of binary
$errpt      = "/usr/bin/errpt";                               	#location of binary
$hostname   = "/usr/bin/hostname";                             	#location of binary
$oslevel    = "/usr/bin/oslevel";                              	#location of binary
$netstat    = "/usr/bin/netstat";                              	#location of binary
$sysdumpdev = "/usr/bin/sysdumpdev";                           	#location of binary
$ping       = "/usr/sbin/ping";                           	#location of binary
$nfso       = "/usr/sbin/nfso";                           	#location of binary
$lsvg       = "/usr/sbin/lsvg";                           	#location of binary
$lsfs       = "/usr/sbin/lsfs";                           	#location of binary
$lsps       = "/usr/sbin/lsps";                           	#location of binary
$ntpq       = "/usr/sbin/ntpq";                           	#location of binary
$mount      = "/usr/sbin/mount";	                      	#location of binary
$uname      = "/usr/bin/uname";		                      	#location of binary
$iostat     = "/usr/bin/iostat";	                      	#location of binary
$verbose    = "no";                                        	#yes/no flag to increase verbosity for debugging
$date       = `date`;  chomp $date;                        	#get the current date




sub sanity_checks {
   #
   print "running sanity_checks subroutine \n" if ($verbose eq "yes");
   #
   $_ = $df; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $ps; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lslpp; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $netstat; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $hostname; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $oslevel; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $errpt; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $sysdumpdev; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $ping; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $nfso; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsvg; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsfs; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsps; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $ntpq; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $mount; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $uname; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $iostat; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   #
   # confirm this machine is running AIX
   $cmd = "$uname";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {					#read a line from the filehandle
      unless ( /AIX/ ) {				#confirm system is running AIX
         print "   ERROR: This script only runs on AIX \n";
         exit;
      } 						#end of unless block
   } 							#end of while loop 
   close IN;						#close filehandle

}                                                       #end of subroutine



sub print_html_header {
   #
   print "running print_html_header subroutine \n" if ($verbose eq "yes");
   #
   # print HTML headers 
   print "<html><head><META http-equiv=refresh content=60><title>AIX health status</title></head><body> \n";
   print "<p>This report was automatically generated by the $0 script at $date \n";
   print "<p>&nbsp; \n";
   #
   print "<table border=1> \n";
   print "<tr bgcolor=grey><td>Check Name <td>Status <td>Notes \n";
}                                                     		#end of subroutine



sub check_hostname {
   #
   print "running check_hostname subroutine \n" if ($verbose eq "yes");
   #
   $cmd = "$hostname";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {					#read a line from the filehandle
      if ( /([a-zA-Z0-9_\-\.]+)/ ) {			#find the hostname
         print "   found hostname $1 \n" if ($verbose eq "yes");
         $checks{hostname}{hostname} = $1; 		#assign value to hash
      } 						#end of if block
   } 							#end of while loop 
   close IN;						#close filehandle
   #
   if ($checks{hostname}{hostname}) {
      print "<tr><td>Hostname <td bgcolor=green> OK <td> hostname is: $checks{hostname}{hostname} \n"; 
   } else {
      print "<tr><td>Hostname <td bgcolor=red> WARNING <td> Could not determine hostname  \n";
   } 
   if ( $checks{hostname}{hostname} =~ "localhost" ) {
      print "<tr><td>Hostname <td bgcolor=red> WARNING <td> Hostname is set to $checks{hostname}{hostname}. This is the initial default, which indicates the hostname has not yet been set. Please set the hostname with: smit hostname  \n";
   }
}                                                       #end of subroutine




sub check_oslevel {
   #
   print "running check_oslevel subroutine \n" if ($verbose eq "yes");
   #
   $cmd = "$oslevel -s";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {					#read a line from the filehandle
      if ( /([0-9\-]+)/ ) {				#find the hostname
         print "   found oslevel $1 \n" if ($verbose eq "yes");
         $checks{oslevel}{oslevel} = $1; 			#assign value to hash
      } 						#end of if block
   } 							#end of while loop 
   close IN;						#close filehandle
   #
   if ($checks{oslevel}{oslevel}) {
      print "<tr><td>AIX version <td bgcolor=green> OK <td> AIX version $checks{oslevel}{oslevel} \n"; 
   } else {
      print "<tr><td>AIX version <td bgcolor=red> WARNING <td> Could not determine installed AIX version  \n";
   } 
}                                                       #end of subroutine



sub check_sshd {
   #
   print "running check_sshd subroutine \n" if ($verbose eq "yes");
   #
   # You should get output similar to one of the following:
   #  #  lslpp -l | grep openssh
   #    openssh                    5.5.0.1  COMMITTED  OpenSSH 5.5p1 Portable for AIX
   #    openssh.base.client     6.0.0.6103  COMMITTED  Open Secure Shell Commands
   #    openssh.base.server     6.0.0.6103  COMMITTED  Open Secure Shell Server
   #
   #
   # confirm the OpenSSH filesets are installed
   #
   $cmd = "$lslpp -l";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {					#read a line from the filehandle
      if ( /^ +openssh +([0-9\.]+) +COMMITTED/ ) {	#portable OpenSSH - not supplied by IBM as part of AIX
         print "   found $_ \n" if ($verbose eq "yes");
         $checks{sshd}{version} = $1;			#store version number
      } 						#end of if block
      if ( /^ +openssh.base.server +([0-9\.]+) +COMMITTED/ ) {	#ssh package bundled with AIX 
         print "   found $_ \n" if ($verbose eq "yes");
         $checks{sshd}{version} = $1;			#store version number
      } 						#end of if block
   } 							#end of while loop 
   close IN;						#close filehandle
   #
   # confirm the OpenSSH daemon is running   xxxx this section not working - regex bug xxx

   #
   $checks{sshd}{running} = ""; 			#initialize variable
   $cmd = "$ps -ef";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {					#read a line from the filehandle
      $checks{sshd}{running} = "yes" if ( /\/usr\/local\/sbin\/sshd/ );
      $checks{sshd}{running} = "yes" if ( /\/usr\/sbin\/sshd/ );
   } 							#end of while loop 
   close IN;						#close filehandle
   #
   if ( ($checks{sshd}{version}) && ($checks{sshd}{running} eq "yes") ) {
      print "<tr><td>SSH daemon <td bgcolor=green> OK <td> openssh version $checks{sshd}{version} is running \n"; 
   } 
   if ( ($checks{sshd}{version}) && ($checks{sshd}{running} ne "yes") ) {
      print "<tr><td>SSH daemon <td bgcolor=red> WARNING <td> openssh version $checks{sshd}{version} is installed, but is not currently running.  <br>Please start ssh daemon with: <br> startsrc -s sshd \n"; 
   } 
   if ( ! ($checks{sshd}{version}) ) {
      print "<tr><td>SSH daemon <td bgcolor=red> WARNING <td> Could not determine installed version of OpenSSH \n";
   } 
}                                                       #end of subroutine





sub check_processes {
   #
   print "running check_processes subroutine \n" if ($verbose eq "yes");
   #
   # confirm important processes are running
   # 
   $checks{processes}{cron}      = "NOT running";  		#initialize variable
   $checks{processes}{srcmstr}   = "NOT running";  		#initialize variable
   $checks{processes}{xntpd}     = "NOT running";  		#initialize variable
   $checks{processes}{qdaemon}   = "NOT running";  		#initialize variable
   $checks{processes}{syslogd}   = "NOT running";  		#initialize variable
   $checks{processes}{inetd}     = "NOT running";  		#initialize variable
   # 
   $cmd = "$ps -ef";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {                                       	#read a line from the filehandle
      $checks{processes}{cron}      = "running" if ( /\/usr\/sbin\/cron/     );
      $checks{processes}{srcmstr}   = "running" if ( /\/usr\/sbin\/srcmstr/  );
      $checks{processes}{xntpd}     = "running" if ( /\/usr\/sbin\/xntpd/    );
      $checks{processes}{qdaemon}   = "running" if ( /\/usr\/sbin\/qdaemon/  );
      $checks{processes}{syslogd}   = "running" if ( /\/usr\/sbin\/syslogd/  );
      $checks{processes}{inetd}     = "running" if ( /\/usr\/sbin\/inetd/    );
   }                   						#end of while loop
   close IN;     	        				#close filehandle
   #
   #
   $bgcolor = "green";  					#initialize variable
   $bgcolor = "orange" if ( $checks{processes}{cron}    eq "NOT running" );
   $bgcolor = "orange" if ( $checks{processes}{srcmstr} eq "NOT running" );
   $bgcolor = "orange" if ( $checks{processes}{xntpd}   eq "NOT running" );
   $bgcolor = "orange" if ( $checks{processes}{qdaemon} eq "NOT running" );
   $bgcolor = "orange" if ( $checks{processes}{syslogd} eq "NOT running" );
   $bgcolor = "orange" if ( $checks{processes}{inetd}   eq "NOT running" );
   #
   print "<tr><td>processes <td bgcolor=green>  OK      <td> \n" if ( $bgcolor eq "green" );
   print "<tr><td>processes <td bgcolor=orange> WARNING <td> \n" if ( $bgcolor eq "orange" );
   print " <br>cron    is $checks{processes}{cron}    \n";
   print " <br>srcmstr is $checks{processes}{srcmstr} \n";
   print " <br>xntpd   is $checks{processes}{xntpd}   \n";
   print " <br>syslogd is $checks{processes}{syslogd} \n";
   print " <br>inetd   is $checks{processes}{inetd}   \n";
}                                                     		#end of subroutine



sub check_dns {
   #
   print "running check_dns subroutine \n" if ($verbose eq "yes");
   #
   $checks{dns}{count} = 0;			#initialize variable
   if ( -f "/etc/resolv.conf" ) {
      open (IN,"/etc/resolv.conf");
      while (<IN>) {					#read a line from the filehandle
         if ( /^nameserver[ \t]+([0-9\.]+)/ ) {		#count up all the name servers listed in /etc/resolv.conf
            print "   found nameserver $1 \n" if ($verbose eq "yes");
            $checks{dns}{count}++; 			#increment counter
            $checks{dns}{server1} = $1 if $checks{dns}{count} == 1;	#save the name of the DNS server
            $checks{dns}{server2} = $1 if $checks{dns}{count} == 2;	#save the name of the DNS server
            $checks{dns}{server3} = $1 if $checks{dns}{count} == 3;	#save the name of the DNS server
         } 						#end of if block
      } 						#end of while loop 
      close IN;						#close filehandle
   }							#end of if block
   #
   # confirm we can ping the DNS servers
   #
   $checks{dns}{server1_pingable} = "";					#initialize variable
   $checks{dns}{server2_pingable} = "";					#initialize variable
   $checks{dns}{server3_pingable} = "";					#initialize variable
   # 
   if ( defined($checks{dns}{server1}) ) {				#confirm that DNS server exists in /etc/resolv.conf
      $cmd = "$ping -c 1 $checks{dns}{server1}";			#ping a particular DNS server
      print "   running command: $cmd \n" if ($verbose eq "yes");
      open (IN,"$cmd |");
      while (<IN>) {							#read a line from the filehandle
         $checks{dns}{server1_pingable} = "no"  if ( /100\% packet loss/ );
         $checks{dns}{server1_pingable} = "yes" if ( /1 packets transmitted, 1 packets received, 0\% packet loss/ );
      } 								#end of while loop 
      close IN;								#close filehandle
   } 									#end of if block
   if ( defined($checks{dns}{server2}) ) {				#confirm that DNS server exists in /etc/resolv.conf
      $cmd = "$ping -c 1 $checks{dns}{server2}";			#ping a particular DNS server
      print "   running command: $cmd \n" if ($verbose eq "yes");
      open (IN,"$cmd |");
      while (<IN>) {							#read a line from the filehandle
         $checks{dns}{server2_pingable} = "no"  if ( /100\% packet loss/ );
         $checks{dns}{server2_pingable} = "yes" if ( /1 packets transmitted, 1 packets received, 0\% packet loss/ );
      } 								#end of while loop 
      close IN;								#close filehandle
   } 									#end of if block
   if ( defined($checks{dns}{server3}) ) {				#confirm that DNS server exists in /etc/resolv.conf
      $cmd = "$ping -c 1 $checks{dns}{server3}";			#ping a particular DNS server
      print "   running command: $cmd \n" if ($verbose eq "yes");
      open (IN,"$cmd |");
      while (<IN>) {							#read a line from the filehandle
         $checks{dns}{server3_pingable} = "no"  if ( /100\% packet loss/ );
         $checks{dns}{server3_pingable} = "yes" if ( /1 packets transmitted, 1 packets received, 0\% packet loss/ );
      } 								#end of while loop 
      close IN;								#close filehandle
   } 									#end of if block
   # 
   # 
   if ( $checks{dns}{count} == 0 ) {
      print "<tr><td>DNS <td bgcolor=red> WARNING <td> Could not find nameserver entries in /etc/resolv.conf <br>This means that name resolution via DNS is not working.  Please add name servers to /etc/resolv.conf \n";
   } 
   if ( ($checks{dns}{count} == 1) && ($checks{dns}{server1_pingable} eq "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> WARNING <td> Only one nameserver entry found in /etc/resolv.conf <br>To avoid a single point of failure, please define at least two nameserver entries in /etc/resolv.conf <br> $checks{dns}{server1} responds to ping\n";
   } 
   if ( ($checks{dns}{count} == 1) && ($checks{dns}{server1_pingable} ne "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> WARNING <td> Only one nameserver entry found in /etc/resolv.conf <br>To avoid a single point of failure, please define at least two nameserver entries in /etc/resolv.conf <br> $checks{dns}{server1} not pingable\n";
   } 
   if ( ($checks{dns}{count} == 2) && ($checks{dns}{server1_pingable} eq "yes") && ($checks{dns}{server2_pingable} eq "yes") ) {
      print "<tr><td>DNS <td bgcolor=green> OK <td> found two DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} responds to ping <br> $checks{dns}{server2} responds to ping\n";
   } 
   if ( ($checks{dns}{count} == 2) && ($checks{dns}{server1_pingable} ne "yes") && ($checks{dns}{server2_pingable} eq "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> WARNING <td> found two DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} does NOT respond to ping <br> $checks{dns}{server2} responds to ping\n";
   } 
   if ( ($checks{dns}{count} == 2) && ($checks{dns}{server1_pingable} eq "yes") && ($checks{dns}{server2_pingable} ne "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> WARNING <td> found two DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} responds to ping <br> $checks{dns}{server2} does NOT respond to ping\n";
   } 
   if ( ($checks{dns}{count} == 2) && ($checks{dns}{server1_pingable} ne "yes") && ($checks{dns}{server2_pingable} ne "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> WARNING <td> found two DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} does NOT respond to ping <br> $checks{dns}{server2} does NOT respond to ping\n";
   } 
   if ( ($checks{dns}{count} == 3) && ($checks{dns}{server1_pingable} eq "yes") && ($checks{dns}{server2_pingable} eq "yes") && ($checks{dns}{server3_pingable} eq "yes") ) {
      print "<tr><td>DNS <td bgcolor=green> OK <td> found three DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} responds to ping <br> $checks{dns}{server2} responds to ping <br> $checks{dns}{server3} responds to ping \n";
   } 
   if ( ($checks{dns}{count} == 3) && ($checks{dns}{server1_pingable} ne "yes") && ($checks{dns}{server2_pingable} eq "yes") && ($checks{dns}{server3_pingable} eq "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> OK <td> found three DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} does NOT respond to ping <br> $checks{dns}{server2} responds to ping <br> $checks{dns}{server3} responds to ping \n";
   } 
   if ( ($checks{dns}{count} == 3) && ($checks{dns}{server1_pingable} ne "yes") && ($checks{dns}{server2_pingable} ne "yes") && ($checks{dns}{server3_pingable} eq "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> OK <td> found three DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} does NOT respond to ping <br> $checks{dns}{server2} does NOT respond to ping <br> $checks{dns}{server3} responds to ping \n";
   } 
   if ( ($checks{dns}{count} == 3) && ($checks{dns}{server1_pingable} ne "yes") && ($checks{dns}{server2_pingable} ne "yes") && ($checks{dns}{server3_pingable} ne "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> OK <td> found three DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} does NOT respond to ping <br> $checks{dns}{server2} does NOT respond to ping <br> $checks{dns}{server3} does NOT respond to ping \n";
   } 
   if ( ($checks{dns}{count} == 3) && ($checks{dns}{server1_pingable} eq "yes") && ($checks{dns}{server2_pingable} ne "yes") && ($checks{dns}{server3_pingable} ne "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> OK <td> found three DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} responds to ping <br> $checks{dns}{server2} does NOT respond to ping <br> $checks{dns}{server3} responds to ping \n";
   } 
   if ( ($checks{dns}{count} == 3) && ($checks{dns}{server1_pingable} eq "yes") && ($checks{dns}{server2_pingable} eq "yes") && ($checks{dns}{server3_pingable} ne "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> OK <td> found three DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} responds to ping <br> $checks{dns}{server2} responds to ping <br> $checks{dns}{server3} does NOT respond to ping \n";
   } 
   if ( ($checks{dns}{count} == 3) && ($checks{dns}{server1_pingable} eq "yes") && ($checks{dns}{server2_pingable} ne "yes") && ($checks{dns}{server3_pingable} eq "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> OK <td> found three DNS server entries in /etc/resolv.conf <br> $checks{dns}{server1} responds to ping <br> $checks{dns}{server2} does NOT respond to ping <br> $checks{dns}{server3} is  pingable \n";
   } 
   if ( ($checks{dns}{count} == 3) && ($checks{dns}{server1_pingable} ne "yes") && ($checks{dns}{server2_pingable} eq "yes") && ($checks{dns}{server3_pingable} ne "yes") ) {
      print "<tr><td>DNS <td bgcolor=orange> OK <td> found three time server entries in /etc/resolv.conf <br> $checks{dns}{server1} does NOT respond to ping <br> $checks{dns}{server2} responds to ping <br> $checks{dns}{server3} does NOT respond to ping \n";
   } 
   if ( $checks{dns}{count} > 3 ) {
      print "<tr><td>DNS <td bgcolor=orange> WARNING <td> There are $checks{dns}{count} nameserver entries in /etc/resolv.conf, but the name resolver client only supports a maximum of 3.  <br>Please reduce the number of nameserver entries in /etc/resolv.conf \n";
   } 
   #
}                                                       #end of subroutine




sub check_ntp {
   #
   print "running check_ntp subroutine \n" if ($verbose eq "yes");
   #
   $checks{ntp}{count} = 0;			#initialize variable
   if ( -f "/etc/ntp.conf" ) {
      open (IN,"/etc/ntp.conf");
      while (<IN>) {							#read a line from the filehandle
         if ( /^server[ \t]+([a-zA-Z0-9\.]+)/ ) {			#count up all the NTP servers listed in /etc/ntp.conf
            print "   found ntp server $1 \n" if ($verbose eq "yes");
            $checks{ntp}{count}++; 					#increment counter
            $checks{ntp}{server1} = $1 if $checks{ntp}{count} == 1;	#save the name of the NTP server
            $checks{ntp}{server2} = $1 if $checks{ntp}{count} == 2;	#save the name of the NTP server
            $checks{ntp}{server3} = $1 if $checks{ntp}{count} == 3;	#save the name of the NTP server
         } 								#end of if block
      } 								#end of while loop 
      close IN;								#close filehandle
   }									#end of if block
   #
   # confirm we can ping the NTP servers
   #
   $checks{ntp}{server1_pingable} = "";					#initialize variable
   $checks{ntp}{server2_pingable} = "";					#initialize variable
   $checks{ntp}{server3_pingable} = "";					#initialize variable
   #
   if ( defined($checks{ntp}{server1}) ) {				#confirm that NTP server exists in ntp.conf
      $cmd = "$ping -c 1 $checks{ntp}{server1}";			#ping a particular NTP server
      print "   running command: $cmd \n" if ($verbose eq "yes");
      open (IN,"$cmd |");
      while (<IN>) {							#read a line from the filehandle
         $checks{ntp}{server1_pingable} = "no"  if ( /100\% packet loss/ );
         $checks{ntp}{server1_pingable} = "yes" if ( /1 packets transmitted, 1 packets received, 0\% packet loss/ );
      } 								#end of while loop 
      close IN;								#close filehandle
   } 									#end of if block
   if ( defined($checks{ntp}{server2}) ) {				#confirm that NTP server exists in ntp.conf
      $cmd = "$ping -c 1 $checks{ntp}{server2}";			#ping a particular NTP server
      print "   running command: $cmd \n" if ($verbose eq "yes");
      open (IN,"$cmd |");
      while (<IN>) {							#read a line from the filehandle
         $checks{ntp}{server2_pingable} = "no"  if ( /100\% packet loss/ );
         $checks{ntp}{server2_pingable} = "yes" if ( /1 packets transmitted, 1 packets received, 0\% packet loss/ );
      } 								#end of while loop 
      close IN;								#close filehandle
   } 									#end of if block
   if ( defined($checks{ntp}{server3}) ) {				#confirm that NTP server exists in ntp.conf
      $cmd = "$ping -c 1 $checks{ntp}{server3}";			#ping a particular NTP server
      print "   running command: $cmd \n" if ($verbose eq "yes");
      open (IN,"$cmd |");
      while (<IN>) {							#read a line from the filehandle
         $checks{ntp}{server3_pingable} = "no"  if ( /100\% packet loss/ );
         $checks{ntp}{server3_pingable} = "yes" if ( /1 packets transmitted, 1 packets received, 0\% packet loss/ );
      } 								#end of while loop 
      close IN;								#close filehandle
   } 									#end of if block
   #
   #
   #
   # check time synchronization to ensure the clock is not drifting
   #
   # In the following example, the "poll" column refers to how often (in seconds) the client will poll
   #
   # In this example, the "when" column refers to how many seconds ago the client contacted the server.
   # If the "when" column goes for a long time with contacting the time server, the value can change from
   # seconds to minutes/hours/days.  For example, if the client has not been able to contact the time server
   # for 27 days, the when column would be: 27d
   #
   # The "st" column is for the stratum of the time server.  This value should be between 0 and 15.  Please
   # note that if this value is 16, that represents an invalid value means the NTP client will not consider
   # using that server for time synchronization.  The cause is usually one of the following:
   #   - time provider not synchronized
   #   - configured source does not exist
   #   - ntp server not running
   #
   # Please note that the delay, offset, and disp columns are all in milliseconds.
   #
   # Command output will look similar to the following:
   #  # ntpq -p
   #     remote           refid      st t when poll reach   delay   offset    disp
   # ==============================================================================
   # *vmdc2.example.co ntp2.torix.ca    2 u  452 1024  377     0.85    1.775    3.83
   #
   $checks{ntp}{stratum} = 9999; 					#initialize hash element
   $checks{ntp}{when}    = 9999; 					#initialize hash element
   $checks{ntp}{offset}  = 9999; 					#initialize hash element
   $cmd = "$ntpq -p";							#check for time sync with NTP peers
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {							#read a line from the filehandle
      next if (/ +remote/); 						#skip header line
      next if (/========/); 						#skip header line
      if ( /^\*[a-zA-Z0-9_\-\.]+ +[a-zA-Z0-9_\-\.]+ +([0-9]+) +[a-z]+ +([0-9]+) +[0-9]+ +[0-9]+ +[0-9\.]+ +([0-9\.\-]+) +[0-9\.]+/ ) {
         print "  found ntp peer $_ \n" if ($verbose eq "yes");
         $checks{ntp}{stratum} = $1; 					#assign value to hash
         $checks{ntp}{when}    = $2; 					#assign value to hash
         $checks{ntp}{offset}  = $3; 					#assign value to hash
         $checks{ntp}{offset}  = sprintf("%.0f", $checks{ntp}{offset});	#truncate to zero decimal places
      } 								#end of if block
   } 									#end of while loop 
   close IN;								#close filehandle
   # 
   # 
   #
   # Generate HTML output
   #
   print "<tr><td>NTP  \n";
   #
   $bgcolor = "green"; 							#initialize variable
   $bgcolor = "red"    if ($checks{ntp}{stratum} > 15    );
   $bgcolor = "red"    if ($checks{ntp}{stratum} < 0     );
   $bgcolor = "red"    if ($checks{ntp}{when}    > 2000  );
   $bgcolor = "red"    if ($checks{ntp}{offset}  > 1000  );
   $bgcolor = "red"    if ( $checks{ntp}{count} == 0     );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 1) && ($checks{ntp}{server1_pingable} ne "yes") );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 2) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} eq "yes") );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 2) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} ne "yes") );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 2) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} ne "yes") );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} eq "yes") && ($checks{ntp}{server3_pingable} eq "yes") );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} ne "yes") && ($checks{ntp}{server3_pingable} eq "yes") );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} ne "yes") && ($checks{ntp}{server3_pingable} ne "yes") );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} eq "yes") && ($checks{ntp}{server3_pingable} ne "yes") );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} ne "yes") && ($checks{ntp}{server3_pingable} eq "yes") );
   $bgcolor = "orange" if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} eq "yes") && ($checks{ntp}{server3_pingable} ne "yes") );
   $bgcolor = "orange" if ( $checks{ntp}{count} > 3 );
   print "<td bgcolor=red>    WARNING \n" if ($bgcolor eq "red");		#print the second column
   print "<td bgcolor=orange> WARNING \n" if ($bgcolor eq "orange");		#print the second column
   print "<td bgcolor=green>  OK      \n" if ($bgcolor eq "green");		#print the second column
   #
   # print the third column
   $_ = "";									#initialize variable
   if ( $checks{processes}{xntpd} eq "running" ) {
      $_ = "$_  <br>xntpd daemon is running";
   } else {
      $_ = "$_  <br>WARNING: xntpd daemon is NOT running";
   }

   if ( ($checks{ntp}{stratum} > 0) && ($checks{ntp}{stratum} < 15) ) {
      $_ = "$_  <br>time server stratum is $checks{ntp}{stratum} ";
   } else {
      $_ = "$_  <br>WARNING: time server stratum is $checks{ntp}{stratum} (must be between 0-15)";
   }

   if ( $checks{ntp}{when} < 2000  ) {
      $_ = "$_  <br>last time sync was $checks{ntp}{when} seconds ago ";
   } else {
      $_ = "$_  <br>WARNING: last time sync was $checks{ntp}{when} seconds ago ";
   }
   #
   if ( $checks{ntp}{count} == 0 ) {
      $_ = "$_ <br> WARNING: Could not find time server entries in /etc/ntp.conf <br>This machine may not be keeping accurate time.  Please add time servers to /etc/ntp.conf \n";
   } 
   if ( ($checks{ntp}{count} == 1) && ($checks{ntp}{server1_pingable} eq "yes") ) {
      $_ = "$_ <br> found one time server entry in /etc/ntp.conf (two is preferred, but one will do) <br> $checks{ntp}{server1} responds to ping\n";
   } 
   if ( ($checks{ntp}{count} == 1) && ($checks{ntp}{server1_pingable} ne "yes") ) {
      $_ = "$_ <br> found one time server entry in /etc/ntp.conf (two is preferred, but one will do) <br> $checks{ntp}{server1} is not pingable\n";
   } 
   if ( ($checks{ntp}{count} == 2) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} eq "yes") ) {
      $_ = "$_ <br> found two time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} responds to ping <br> $checks{ntp}{server2} responds to ping\n";
   } 
   if ( ($checks{ntp}{count} == 2) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} eq "yes") ) {
      $_ = "$_ <br> found two time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} does NOT respond to ping <br> $checks{ntp}{server2} responds to ping\n";
   } 
   if ( ($checks{ntp}{count} == 2) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} ne "yes") ) {
      $_ = "$_ <br> found two time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} responds to ping <br> $checks{ntp}{server2} does NOT respond to ping\n";
   } 
   if ( ($checks{ntp}{count} == 2) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} ne "yes") ) {
      $_ = "$_ <br> found two time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} does NOT respond to ping <br> $checks{ntp}{server2} does NOT respond to ping\n";
   } 
   if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} eq "yes") && ($checks{ntp}{server3_pingable} eq "yes") ) {
      $_ = "$_ <br> found three time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} responds to ping <br> $checks{ntp}{server2} responds to ping <br> $checks{ntp}{server3} responds to ping \n";
   } 
   if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} eq "yes") && ($checks{ntp}{server3_pingable} eq "yes") ) {
      $_ = "$_ <br> found three time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} does NOT respond to ping <br> $checks{ntp}{server2} responds to ping <br> $checks{ntp}{server3} responds to ping \n";
   } 
   if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} ne "yes") && ($checks{ntp}{server3_pingable} eq "yes") ) {
      $_ = "$_ <br> found three time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} does NOT respond to ping <br> $checks{ntp}{server2} does NOT respond to ping <br> $checks{ntp}{server3} responds to ping \n";
   } 
   if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} ne "yes") && ($checks{ntp}{server3_pingable} ne "yes") ) {
      $_ = "$_ <br> found three time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} does NOT respond to ping <br> $checks{ntp}{server2} does NOT respond to ping <br> $checks{ntp}{server3} does NOT respond to ping \n";
   } 
   if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} ne "yes") && ($checks{ntp}{server3_pingable} ne "yes") ) {
      $_ = "$_ <br> found three time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} responds to ping <br> $checks{ntp}{server2} does NOT respond to ping <br> $checks{ntp}{server3} responds to ping \n";
   } 
   if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} eq "yes") && ($checks{ntp}{server3_pingable} ne "yes") ) {
      $_ = "$_ <br> found three time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} responds to ping <br> $checks{ntp}{server2} responds to ping <br> $checks{ntp}{server3} does NOT respond to ping \n";
   } 
   if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} eq "yes") && ($checks{ntp}{server2_pingable} ne "yes") && ($checks{ntp}{server3_pingable} eq "yes") ) {
      $_ = "$_ <br> found three time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} responds to ping <br> $checks{ntp}{server2} does NOT respond to ping <br> $checks{ntp}{server3} responds to ping \n";
   } 
   if ( ($checks{ntp}{count} == 3) && ($checks{ntp}{server1_pingable} ne "yes") && ($checks{ntp}{server2_pingable} eq "yes") && ($checks{ntp}{server3_pingable} ne "yes") ) {
      $_ = "$_ <br> found three time server entries in /etc/ntp.conf <br> $checks{ntp}{server1} does NOT respond to ping <br> $checks{ntp}{server2} responds to ping <br> $checks{ntp}{server3} does NOT respond to ping \n";
   } 
   if ( $checks{ntp}{count} > 3 ) {
      $_ = "$_ <br> WARNING: There are $checks{ntp}{count} nameserver entries in /etc/ntp.conf.  Any more than 3 is overkill. Try reducing the name servers in /etc/ntp.conf \n";
   } 
   print "<td> $_ \n";
}                                   					#end of subroutine





sub check_default_route {
   #
   print "running check_default_route subroutine \n" if ($verbose eq "yes");
   #
   # Command output will look similar to:
   # Route Tree for Protocol Family 2 (Internet):
   # default            10.0.0.2          UG        0      2033 en0      -      -
   # 10.0.0.0           10.0.0.29         UHSb      0         0 en0      -      -   =>
   # 10/24              10.0.0.29         U         6   5461550 en0      -      -
   #
   #
   # confirm a default gateway exists
   #
   $checks{defaultroute}{count} = 0;			#initialize variable
   $cmd = "$netstat -rn";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {					#read a line from the filehandle
      if ( /^default[ \t]+([0-9\.]+)/ ) {		#count up all the name servers listed in /etc/resolv.conf
         print "   found default route $1 \n" if ($verbose eq "yes");
         $checks{defaultroute}{route} = $1;		#assign value to hash
         $checks{defaultroute}{count}++;		#increment counter
      } 						#end of if block
   } 							#end of while loop 
   close IN;						#close filehandle
   #
   # confirm we can ping the default gateway
   #
   $checks{defaultroute}{pingable} = "";		#initialize variable
   if ( defined($checks{defaultroute}{route}) ) {	#confirm that a default route exists before trying to ping it
      $cmd = "$ping -c 1 $checks{defaultroute}{route}";
      print "   running command: $cmd \n" if ($verbose eq "yes");
      open (IN,"$cmd |");
      while (<IN>) {					#read a line from the filehandle
         $checks{defaultroute}{pingable} = "no"  if ( /100\% packet loss/ );
         $checks{defaultroute}{pingable} = "yes" if ( /1 packets transmitted, 1 packets received, 0\% packet loss/ );
      } 						#end of while loop 
      close IN;						#close filehandle
   } 							#end of if block
   #
   if ( $checks{defaultroute}{count} == 0 ) {
      print "<tr><td>Default Route <td bgcolor=red> WARNING <td> Could not find default route in routing table <br>This machine cannot communicate outside the local subnet.  Please add a default route from smit tcpip \n";
   } 
   if ( ($checks{defaultroute}{count} == 1) && ($checks{defaultroute}{pingable} eq "yes") ) {
      print "<tr><td>Default Route <td bgcolor=green> OK <td> default gateway is $checks{defaultroute}{route} <br>default gateway responds to ping\n";
   } 
   if ( ($checks{defaultroute}{count} == 1) && ($checks{defaultroute}{pingable} ne "yes") ) {
      print "<tr><td>Default Route <td bgcolor=red> WARNING <td> default gateway is $checks{defaultroute}{route} <br>default gateway does not respond to ping\n";
   } 
   if ( $checks{defaultroute}{count} > 1 ) {
      print "<tr><td>Default Route <td bgcolor=red> WARNING <td> Found multiple default routes.  <br>Please review the output of \"netstat -rn\" to see all the routes.  <br>You should only have one default route.  <br>Sometimes a misconfigured NIM server puts in a bogus route on NIM clients  \n";
   } 
}                                                       #end of subroutine






sub check_errpt {
   #
   print "running check_errpt subroutine \n" if ($verbose eq "yes");
   #
   # Command output will look similar to:
   # # errpt
   #
   $checks{errpt}{count}   = 0;				#initialize variable
   $checks{errpt}{entries} = "";			#initialize variable
   $cmd = "$errpt";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {					#read a line from the filehandle
      if ( /[a-zA-Z0-9]+/ ) {				#find errpt entries
         $checks{errpt}{count}++; 			#increment counter
         $checks{errpt}{entries} = "$_  $checks{errpt}{entries}";
      } 						#end of if block
   } 							#end of while loop 
   close IN;						#close filehandle
   #
   if ( $checks{errpt}{count} == 0 ) {
      print "<tr><td>Error report <td bgcolor=green> OK <td> No errpt entries found  \n";
   } 
   if ( $checks{errpt}{count} > 0 ) {
      print "<tr><td>Error report <td bgcolor=red> WARNING <td> Found errpt entries: <br> $checks{errpt}{entries} \n";
   } 
   #
}                                                       #end of subroutine




sub check_sendmail_queue {
   #
   print "running check_sendmail_queue subroutine \n" if ($verbose eq "yes");
   #
   # Note that each message will be made up of two files:
   #    d?????? contains the actual message body
   #    q?????? contains the message headers (to/from/subject/date)
   # So, when checking the number of files in the mail queue, divide the total by two (use awk for division)
   #
   $checks{sendmail}{queue_dir} = "/var/spool/mqueue";		#location of sendmail queue
   $checks{sendmail}{count} = 0;  				#initialize variable
   opendir (DIR, $checks{sendmail}{queue_dir}) or die "Cannot open $checks{sendmail}{queue_dir} directory: $! \n";
   @_ = readdir DIR; 						#put all the filenames into an array
   closedir(DIR);						#close filehandle
   $checks{sendmail}{count} = @_;				#convert number of array elements into a scalar count
   if ( $checks{sendmail}{count} > 0 ) {			#see if there are messages in the sendmail queue
      $checks{sendmail}{count} = $checks{sendmail}{count} / 2;	#divide by 2 because each message is made up of 2 files (d???=message body q???=header)
      $checks{sendmail}{count} = sprintf("%.0f", $checks{sendmail}{count}); #truncate to zero decimal places
   } 								#end of if block
   #
   if ( $checks{sendmail}{count} <= 10 ) {				#do not bother alerting for less than 10 messages
      print "<tr><td>outgoing mail queue <td bgcolor=green> OK <td> No outgoing messages in sendmail queue  \n";
   } 
   if ( $checks{sendmail}{count} > 10 ) {
      print "<tr><td>outgoing mail queue <td bgcolor=orange> WARNING <td> Found $checks{sendmail}{count} messages in sendmail queue in $checks{sendmail}{queue_dir} directory.  Try flushing sendmail queue with:  sendmail -q \n";
   } 
}                                                       #end of subroutine





sub check_mailboxes {
   #
   print "running check_mailboxes subroutine \n" if ($verbose eq "yes");
   #
   # user mailboxes are located at /var/spool/mail/username
   # check each file in /var/spool/mail/* to see if users have too many messages
   # the file at /var/spool/mail/$user is a single file that contains all the mail for that user
   # parse out the From: lines to figure out how many messages are in that file
   #
   $bgcolor = "green";  					#initialize variable
   opendir(DIR, "/var/spool/mail") or die "Could not open directory /var/spool/mail  $! \n";
   while ($filename = readdir(DIR)) {
      print "found filename $filename \n" if ($verbose eq "yes");
      $checks{mailboxes}{$filename} = 0; 			#initialize counter variable
      open (FILE,"/var/spool/mail/$filename") or warn "Cannot open file /var/spool/mail/$filename for reading $! \n";
      while (<FILE>) {
         $checks{mailboxes}{$filename}++ if (/From:/);		#increment counter
         $bgcolor = "orange" if ( $checks{mailboxes}{$filename} > 100 );	#raise an alert if >100 mailbox messages for a user
      } 							#end of while loop
      close FILE; 						#close filehandle
   } 								#end of while loop
   closedir(DIR); 						#close filehandle
   #
   if ( $bgcolor eq "green" ) {
      print "<tr><td>mailboxes <td bgcolor=green> OK <td> User mailboxes are OK  \n";
   } 
   if ( $bgcolor eq "orange" ) {
      print "<tr><td>mailboxes <td bgcolor=orange> WARNING <td> Excessive mail messages found.  Perhaps a cron job is sending output to mail.  \n";
      opendir(DIR, "/var/spool/mail") or die "Could not open directory /var/spool/mail  $! \n";
      while ($filename = readdir(DIR)) {
         if ( $checks{mailboxes}{$filename} > 100 ) {
            print "<br> $filename has $checks{mailboxes}{$filename} mail messages - please login as $filename and run mail command to clean up. \n";
         }  							#end of if block
      }  							#end of while loop
      closedir(DIR); 						#close filehandle
   }  								#end of if block
} 								#end of subroutine





sub check_print_queue {
   #
   print "running check_print_queue subroutine \n" if ($verbose eq "yes");
   #
   #
   $checks{print}{queue_dir} = "/var/spool/lpd/qdir";		#location of print queue
   $checks{print}{count} = 0;  					#initialize variable
   opendir (DIR, $checks{print}{queue_dir}) or die "Cannot open $checks{print}{queue_dir} directory: $! \n";
   @_ = readdir DIR; 						#put all the filenames into an array
   closedir(DIR);						#close filehandle
   $checks{print}{count} = @_;					#convert number of array elements into a scalar count
   #
   if ( $checks{print}{count} <= 3 ) {				#do not bother alerting for less than 3 job in the print queue
      print "<tr><td>print queue <td bgcolor=green> OK <td> No jobs in print queue  \n";
   } 
   if ( $checks{print}{count} > 3 ) {
      print "<tr><td>print queue <td bgcolor=orange> WARNING <td> Found $checks{print}{count} jobs in print queue in $checks{print}{queue_dir} directory.  Please check for a hung print queue with the lpstat command. \n";
   } 
}                                      		  		#end of subroutine




sub check_loopback {
   #
   print "running check_loopback subroutine \n" if ($verbose eq "yes");
   #
   $checks{loopback}{exists} = ""; 				#initialize variable
   open (IN,"/etc/hosts") or warn "ERROR: Could not open /etc/hosts for reading: $! \n";
   while (<IN>) {		 				#read a line from the filehandle
      if (/^127.0.0.1/) {					#find the line that begins with 127.0.0.1
         $checks{loopback}{exists} = "yes" if (/loopback/);   	#confirm loopback entry exists
      } 							#end of if block
   }  								#end of while loop
   close IN;							#close filehandle
   #
   if ( $checks{loopback}{exists} eq "yes" ) {		
      print "<tr><td>loopback <td bgcolor=green> OK <td> loopback entry exists for 127.0.0.1 in /etc/hosts  \n";
   } else {
      print "<tr><td>loopback <td bgcolor=red> WARNING <td> Could not find loopback entry in /etc/hosts.   <br>Name resolution for loopback is required by hostmibd and aixmibd.  ";
      print "                                          <br>Please add the following to /etc/hosts: <br> 127.0.0.1 loopback localhost # loopback (lo0) name/address \n";
   } 
}                                                       	#end of subroutine


sub check_syslog {
   #
   print "running check_syslog subroutine \n" if ($verbose eq "yes");
   #
   if ( -f "/var/adm/messages" ) {
      $checks{var_adm_messages}{exists} = "yes";
      ($device,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/var/adm/messages");
      $checks{var_adm_messages}{mb} = "$size";			#get file size in bytes
      $checks{var_adm_messages}{mb} = $checks{var_adm_messages}{mb} / 1024 / 1024;	#convert bytes to MB
      $checks{var_adm_messages}{mb} = sprintf("%.0f", $checks{var_adm_messages}{mb}); #truncate to zero decimal places
   } else { 
      $checks{var_adm_messages}{exists} = "no";
      $checks{var_adm_messages}{mb} = 0;			#initialize variable
   } 								#end of if/else block
   #
   if ( ($checks{var_adm_messages}{exists} eq "yes") && ($checks{var_adm_messages}{mb} < 10) ) {
      print "<tr><td>syslog <td bgcolor=green> OK <td> /var/adm/messages exists  \n";
   } 
   #
   if ( ($checks{var_adm_messages}{exists} eq "yes") && ($checks{var_adm_messages}{mb} >= 10) ) {
      print "<tr><td>syslog <td bgcolor=orange> OK <td> /var/adm/messages exists, but is $checks{var_adm_messages}{mb} MB in size. ";
      print "               <br> Consider adding a line similar to the following to syslog.conf to automatically rotate this logfile. <br> *.debug /var/adm/messages rotate size 10000k files 4 compress \n";
   } 
   if ( $checks{var_adm_messages}{exists} eq "no" ) {
      print "<tr><td>syslog <td bgcolor=orange> WARNING <td> /var/adm/messages file does not exist.  This means syslog cannot write messages.  <br>Please create file with: <br>touch /var/adm/messages <br>refresh -s syslog  \n";
   } 
}                                                       	#end of subroutine




sub check_wtmp {
   #
   print "running check_wtmp subroutine \n" if ($verbose eq "yes");
   #
   if ( -f "/var/adm/wtmp" ) {
      $checks{var_adm_wtmp}{exists} = "yes";
      ($device,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/var/adm/wtmp");
      $checks{var_adm_wtmp}{mb} = "$size";			#get file size in bytes
      $checks{var_adm_wtmp}{mb} = $checks{var_adm_wtmp}{mb} / 1024 / 1024;	#convert bytes to MB
      $checks{var_adm_wtmp}{mb} = sprintf("%.0f", $checks{var_adm_wtmp}{mb}); #truncate to zero decimal places
   } else { 
      $checks{var_adm_wtmp}{exists} = "no";
      $checks{var_adm_wtmp}{mb} = 0;				#initialize variable
   } 								#end of if/else block
   #
   if ( ($checks{var_adm_wtmp}{exists} eq "yes") && ($checks{var_adm_wtmp}{mb} < 10) ) {
      print "<tr><td>wtmp <td bgcolor=green> OK <td> /var/adm/wtmp exists  \n";
   } 
   if ( ($checks{var_adm_wtmp}{exists} eq "yes") && ($checks{var_adm_wtmp}{mb} >= 10) ) {
      print "<tr><td>syslog <td bgcolor=orange> OK <td> /var/adm/wtmp exists, but is $checks{var_adm_wtmp}{mb} MB in size.  Please rotate the file with these commands:  <br>cp /var/adm/wtmp /var/adm/wtmp.old <br> cp /dev/null /var/adm/wtmp \n";
   } 
   if ( $checks{var_adm_wtmp}{exists} eq "no" ) {
      print "<tr><td>syslog <td bgcolor=orange> WARNING <td> /var/adm/wtmp file does not exist.  This file is used to store the login activity displayed by the /usr/bin/last command.  Please create file with: <br>touch /var/adm/wtmp <br>chown adm:adm /var/adm/wtmp \n";
   } 
}                                                       	#end of subroutine



sub check_system_attention_light {
   #
   print "running check_system_attention_light subroutine \n" if ($verbose eq "yes");
   #
   ####################################################
   # NOTE: This is only valid for systems NOT managed by an HMC
   #       If you run the usysfault command from an HMC-managed system, you will get
   #       the following message:  This command is not supported on this system
   #
   #
   #
   $checks{led}{status} = ""; 					#initialize variable
   if ( ! -f "/usr/lpp/diagnostics/bin/usysfault" ) {		#confirm required file exists
      $cmd = "/usr/lpp/diagnostics/bin/usysfault";
      print "   running command: $cmd \n" if ($verbose eq "yes");
      open (IN,"$cmd |");
      while (<IN>) {						#read a line from the filehandle
         $checks{led}{status} = "normal"        if ( /normal/); 
         $checks{led}{status} = "fault"         if ( /fault/); 
         $checks{led}{status} = "notsupported"  if ( /This command is not supported on this system/); 
      } 							#end of while loop
      close IN;							#close filehandle
   } 								#end of if block
   #
   # this is only valid on standalone machines that are not managed by an HMC/IVM/FSM
   # since this may not be applicable, only show on the HTML report if there is a problem
   if ( $checks{led}{status} eq "fault"  ) {
      print "<tr><td>system attention light <td bgcolor=orange> WARNING <td> System attention light is illuminated.  Please check output of diag and errpt.  <br>When the problem has been resolved, turn off the attention light with: <br> errclear 0 <br> /usr/lpp/diagnostics/bin/usysfault -s normal  \n";
   } 
}                                                       	#end of subroutine




sub check_tsm_client {
   #
   print "running check_tsm_client subroutine \n" if ($verbose eq "yes");
   #
   # If this machine is a TSM client, confirm the dsmsched.log is less than 72 hours old, which indicates a backup within the last 72 hours.
   #
   if ( (-f "/usr/tivoli/tsm/client/ba/bin/dsmsched.log") || (-f "/usr/tivoli/tsm/client/ba/bin64/dsmsched.log") ) {
      $checks{tsm}{dsmsched_log_file} = "/usr/tivoli/tsm/client/ba/bin/dsmsched.log"   if ( -f "/usr/tivoli/tsm/client/ba/bin/dsmsched.log");
      $checks{tsm}{dsmsched_log_file} = "/usr/tivoli/tsm/client/ba/bin64/dsmsched.log" if ( -f "/usr/tivoli/tsm/client/ba/bin64/dsmsched.log");
      ($device,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$checks{tsm}{dsmsched_log_file}");	#get file age
      $epoch = time(); 										#number of seconds since the epoch
      $checks{tsm}{dsmsched_log_daysold} = ( ($epoch - $mtime) * 60 * 60 * 24 ); 		#mtime is last file modification time in seconds since the epoch
      $checks{tsm}{dsmsched_log_daysold} = sprintf("%.0f", $checks{tsm}{dsmsched_log_daysold}); #truncate to zero decimal places
   }                                                       	#end of if block
   #
   # this is only valid on machines that are TSM clients
   if ( defined($checks{tsm}{dsm_sched_file}) && ($checks{tsm}{dsm_sched_daysold} < 3 ) ) {
      print "<tr><td>TSM client <td bgcolor=green> OK <td> TSM client installed last backup ran $checks{tsm}{dsm_sched_daysold} days ago \n";
   } 
   if ( defined($checks{tsm}{dsm_sched_file}) && ($checks{tsm}{dsm_sched_daysold} >= 3 ) ) {
      print "<tr><td>TSM client <td bgcolor=orange> WARNING <td> TSM client is installed, but the most recent backup was $checks{tsm}{dsm_sched_daysold} days ago \n";
   } 
}                                                       	#end of subroutine





sub check_sysdumpdev {
   #
   print "running check_sysdumpdev subroutine \n" if ($verbose eq "yes");
   #
   # check the primary and secondary dump devices
   #
   # By default, AIX will use paging space (/dev/hd6) as the primary dump device, and /dev/sysdumpnull as the secondary dump device
   #
   # We do not want that.  Since AIX cannot mirror its dump device, we want a dump logical volume on each physical disk in rootvg.
   #
   # If the primary dump device is set to /dev/hd6, you will always get an error when you try to
   # varyonvg rootvg after experiencing stale physical partitions after a VIO outage.
   #
   # confirm the primary system dump device exists, and is not set to the paging space
   #
   # The output of the sysdumpdev command will look like this:
   #   primary              /dev/lvdump1
   #   secondary            /dev/lvdump2
   #   copy directory       /var/adm/ras
   #   forced copy flag     TRUE
   #   always allow dump    TRUE
   #   dump compression     ON
   #
   # If the primary device does not exist, the output will look like:
   #   primary              -
   #
   # In some cases, the primary device will be the paging volume:
   #   primary              /dev/hd6
   #
   #
   #
   #
   $checks{sysdumpdev}{primary}   = ""; 					#initialize variable
   $checks{sysdumpdev}{secondary} = ""; 					#initialize variable
   #
   $cmd = "$sysdumpdev -l";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {								#read a line from the filehandle
      $checks{sysdumpdev}{primary}   = $1 if (/^primary +([a-zA-Z0-9_\/]+)/); 	#find the primary dump device
      $checks{sysdumpdev}{secondary} = $1 if (/^secondary +([a-zA-Z0-9_\/]+)/);	#find the secondary dump device
   } 										#end of while loop 
   close IN;									#close filehandle
   #
   if ( $checks{sysdumpdev}{primary} eq "" ) {
      print "<tr><td>system dump device <td bgcolor=orange> WARNING <td> Primary system dump device not found.  This means the system cannot save a dump file in the event of a crash.  <br>Please create a system dump device with: <p> sysdumpdev -p /dev/hd6 \n";
   } 									#end of if block
   if ( $checks{sysdumpdev}{secondary} eq "" ) {
      print "<tr><td>system dump device <td bgcolor=orange> WARNING <td> Secondary system dump device not found.  This means the system cannot save a dump file in the event of a crash.  <br>Please create a system dump device with: <p> sysdumpdev -s /dev/sysdumpnull \n";
   } 									#end of if block
   if ( $checks{sysdumpdev}{primary} eq "\/dev\/hd6" ) {
      print "<tr><td>system dump device <td bgcolor=orange> WARNING <td>primary dump device is set to the paging space $checks{sysdumpdev}{primary}.  We want a dedicated paging space. <br>Please create a Logical Volume of type sysdump, and set it as the primary system dump device with these commands: <br> mklv -t sysdump -y lvdump1 rootvg numLP hdisk# <br> sysdumpdev -P -p /dev/lvdump1 \n";
   } 									#end of if block
   if ( defined($checks{sysdumpdev}{primary}) && ($checks{sysdumpdev}{primary} ne "\/dev\/hd6") ) {
      print "<tr><td>system dump device <td bgcolor=green> OK <td>primary dump device exists: $checks{sysdumpdev}{primary} \n";
   } 									#end of if block
}                                                      			 	#end of subroutine



sub check_nfs_source_port {
   #
   print "running check_nfs_source_port subroutine \n" if ($verbose eq "yes");
   #
   #
   # Confirm the source port for NFS mounts is <1024
   # In this context, "reserved ports" means UDP/TCP ports <1024
   # AIX 4.2 used "reserved ports" as the source ports for NFS mounts
   # AIX 4.2.1 and greater will use any random port
   # This causes problems with some systems that expect the source port to be <1024
   # NIM clients like the NFS mounts used by NIM to use reserved ports
   # Mounts to other UNIX flavors sometimes require reserved ports
   # All in all, it's better just to use reserved ports for broader compatibility.
   #
   #
   $checks{nfs}{reserved_ports} = "";						#initialize variable
   $cmd = "$nfso -o nfs_use_reserved_ports";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {									#read a line from the filehandle
      $checks{nfs}{reserved_ports} = $1 if ( /^nfs_use_reserved_ports = ([0-1])/ );	#find the value of the NFS option
   } 											#end of while loop 
   close IN;										#close filehandle
   #
   if ( $checks{nfs}{reserved_ports} == 1 ) {
      print "<tr><td>NFS reserved ports <td bgcolor=green> OK <td> NFS is using reserved ports.  This is required for NIM and cross-platform compatibility. \n";
   } else { 
      print "<tr><td>NFS reserved ports <td bgcolor=orange> WARNING <td> NFS is not using reserved ports.  <br> This can cause compatibility problems for NIM and other NFS mounts.  <br> Please run the following commands:  <br> $nfso -o nfs_use_reserved_ports=1 #activate now <br> $nfso -p -o nfs_use_reserved_ports=1 #update /etc/tunables/nextboot to make permanent \n";
   } 									#end of if/else block
}                              	                        			 	#end of subroutine



sub check_rctcpip {
   #
   print "running check_rctcpip subroutine \n" if ($verbose eq "yes");
   #
   if ( -f "/etc/rc.tcpip" ) {						#check to see if file exists
      $checks{rctcpip}{exists} = "yes"; 
      ($device,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/etc/rc.tcpip");
      $checks{rctcpip}{bytes}  = $size;					#get file size in bytes
   } else {
      $checks{rctcpip}{exists} = "no";
      $checks{rctcpip}{bytes}  = 0;					#get file size in bytes
   } 									#end of if/else block
   #
   if ( ($checks{rctcpip}{exists} eq "yes") && ($checks{rctcpip}{bytes} > 2048) ) {		#confirm file exists and is at least 2048 bytes
      print "<tr><td>/etc/rc.tcpip <td bgcolor=green> OK <td> /etc/rc.tcpip exists <br>This file starts TCPIP daemons at boot time. \n";
   } 
   if ( ($checks{rctcpip}{exists} eq "yes") && ($checks{rctcpip}{bytes} <= 2048) ) {
      print "<tr><td>/etc/rc.local <td bgcolor=red> WARNING <td> /etc/rc.local exists, but seems unusually small.  Please confirm that all required TCPIP daemons are starting normally from /etc/rc.tcpip \n";
   } 
   if ( $checks{rctcpip}{exists} ne "yes" ) {
      print "<tr><td>/etc/rc.tcpip <td bgcolor=red> WARNING <td> /etc/rc.tcpip does not exist. This file is required to start TCPIP daemons at boot time. Please investigate. <br>HINT: do NOT reboot until you fix up that file! \n";
   } 
}             	                        			 	#end of subroutine





sub check_rclocal {
   #
   print "running check_rclocal subroutine \n" if ($verbose eq "yes");
   #
   if ( -f "/etc/rc.local" ) {						#check to see if file exists
      $checks{rclocal}{exists} = "yes"; 
      ($device,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/etc/rc.local");
      $checks{rclocal}{bytes} = $size;					#get file size in bytes
   } else {
      $checks{rclocal}{exists} = "no";
      $checks{rclocal}{bytes} = 0;					#get file size in bytes
   } 									#end of if/else block
   #
   # If the /etc/rc.local file exists, confirm it is executed at boot time from /etc/inittab
   $checks{rclocal}{autostart} = ""; 					#initialize variable
   if ( -f "/etc/rc.local" ) {						#check to see if file exists
      open (IN,"/etc/inittab") or warn "Cannot open /etc/inittab for reading: $! \n";
      while (<IN>) {							#read a line from the filehandle
         $checks{rclocal}{autostart} = "yes" if ( /^local:2:once:\/etc\/rc.local/ );
      } 								#end of while loop
      close IN;
   } 									#end of if/else block
   #
   if ( ($checks{rclocal}{exists} eq "yes") && ($checks{rclocal}{autostart} eq "yes") ) {
      print "<tr><td>/etc/rc.local <td bgcolor=green> OK <td> /etc/rc.local exists and starts at boot time from /etc/inittab \n";
   } 
   if ( ($checks{rclocal}{exists} eq "yes") && ($checks{rclocal}{autostart} ne "yes") ) {
      print "<tr><td>/etc/rc.local <td bgcolor=red> WARNING <td> /etc/rc.local exists, but does not start automatically at boot time. <br>Please run the following command: <br>  mkitab \"local:2:once:/etc/rc.local >/dev/console 2>\&1\" \n";
   } 
}                                                       		#end of subroutine





# this subroutine is not complete - does not generate html output
sub check_volume_groups {
   #
   print "running check_volume_groups subroutine \n" if ($verbose eq "yes");
   #
   # Confirm all disks in rootvg are active
   #
   # get a list of all disks in rootvg 
   # command output will look similar to:
   #  # lsvg -p rootvg
   #  rootvg:
   #  PV_NAME           PV STATE          TOTAL PPs   FREE PPs    FREE DISTRIBUTION
   #  hdisk0            active            2559        1446        173..448..00..313..512
   #  hdisk1            active            2559        1446        173..448..00..313..512
   #
   $checks{rootvg}{active} = ""; 				#initialize variable
   $cmd = "$lsvg -p rootvg";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");						#open filehandle using command output
   while (<IN>) {                                       	#read a line from the filehandle
      next if (/^rootvg:/);					#skip header row
      next if (/^PV_NAME:/);					#skip header row
      if ( /^(hdisk[0-9]+) +active/ ) {				#see if disk is in an active state
         $checks{rootvg}{active} = "$checks{rootvg}{active} <br> $1 is active ";
      } elsif ( /^(hdisk[0-9]+) +([a-z]+)/ ) {			#look for disks not in an active state
         $checks{rootvg}{active} = "$checks{rootvg}{active} <br> <font color=red> $1 is $2 </font> ";
      } 							#end of if/elsif block
   }                   						#end of while loop
   close IN;     	        				#close filehandle
   #
   #
   # Confirm all disks in rootvg have a boot logical volume
   #
}                                                     		#end of subroutine




sub check_filesystems {
   #
   print "running check_filesystems subroutine \n" if ($verbose eq "yes");
   #
   # Confirm all filesystems are mounted
   #
   #  # lsfs
   # Name            Nodename   Mount Pt               VFS   Size    Options    Auto Accounting
   # /dev/hd4        --         /                      jfs2  2097152 --         yes  no
   # /dev/hd1        --         /home                  jfs2  1048576 --         yes  no
   # /dev/hd2        --         /usr                   jfs2  4194304 --         yes  no
   # /dev/hd9var     --         /var                   jfs2  3145728 --         yes  no
   # /dev/hd3        --         /tmp                   jfs2  1572864 --         yes  no
   # /proc           --         /proc                  procfs --     --         yes  no
   # /s00/qbyte  unix01         /s00/qbyte             nfs    --     bg,soft,intr,nodev,nosuid yes  no
   # /dev/cd0        --         /cdrom                 cdfs   --     --         no   no
   #
   # get list of all local filesystems (skip nfs and cdfs and procfs)
   #
   $cmd = "$lsfs";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");						#open filehandle using command output
   while (<IN>) {                                       	#read a line from the filehandle
      next if (/^Name/);					#skip header row
      next if (/ cdfs /);					#skip cdrom  filesystems
      next if (/ nfs /);					#skip NFS    filesystems
      next if (/ procfs /);					#skip procfs filesystems
      if ( /^([a-zA-Z0-9_\/\-]+) +[\-]+ +([a-zA-Z0-9_\/\.]+) +[a-z0-9]+ +[0-9]+ +[\-]+ +([a-z]+) +[a-z]+/ ) {	#look at filesystem attributes
         chomp $_; 						#remove newline
         print "   found filesystem $_ \n" if ($verbose eq "yes");
         print "   device_name=$1 mount_point=$2 auto_mount=$3 \n" if ($verbose eq "yes");
         $filesystems{$2}{mount_point} = $2; 			#assign value to hash element
         $filesystems{$2}{device}      = $1; 			#assign value to hash element
         $filesystems{$2}{auto_mount}  = $3; 			#assign value to hash element
         $filesystems{$2}{mounted}     = "unknown"; 		#assign value to hash element
      } 
   }                   						#end of while loop
   close IN;     	        				#close filehandle
   #
   # figure out which filesystems are currently mounted
   # command output will look similar to:
   #  # mount
   #   node       mounted        mounted over    vfs       date        options
   # -------- ---------------  ---------------  ------ ------------ ---------------
   #      /dev/hd4         /                jfs2   Oct 17 19:25 rw,log=/dev/hd8
   #      /dev/hd2         /usr             jfs2   Oct 17 19:25 rw,log=/dev/hd8
   #      /dev/hd9var      /var             jfs2   Oct 17 19:25 rw,log=/dev/hd8
   #      /dev/hd3         /tmp             jfs2   Oct 17 19:25 rw,log=/dev/hd8
   #      /dev/hd1         /home            jfs2   Oct 17 19:25 rw,log=/dev/hd8
   #      /proc            /proc            procfs Oct 17 19:25 rw
   #      /dev/hd10opt     /opt             jfs2   Oct 17 19:25 rw,log=/dev/hd8
   #      /dev/lvs00ora    /s00/oracle      jfs2   Oct 17 19:25 rw,log=/dev/lvs00oral
   #      /dev/lvoraback   /oraback         jfs2   Mar 06 11:29 rw,log=INLINE
   #      /dev/lvoraarch   /oraarch         jfs2   Mar 06 11:30 rw,log=INLINE
   #  
   #
   $cmd = "$mount";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");						#open filehandle using command output
   while (<IN>) {                                       	#read a line from the filehandle
      next if (/^ +node/);					#skip header row
      next if (/^\-+/);						#skip header row
      next if (/ nfs /);					#skip NFS    filesystems
      next if (/ cdfs /);					#skip cdfs   filesystems
      next if (/ procfs /);					#skip procfs filesystems
      if ( /^ +([a-zA-Z0-9_\/\-]+) +([a-zA-Z0-9_\/\.]+) +/ ) {	#look at mounted filesystems
         chomp $_; 						#remove newline
         print "   found mounted filesystem $_ \n" if ($verbose eq "yes");
         $filesystems{$2}{mounted} = "yes"; 			#assign value to hash element
      } 
   }                   						#end of while loop
   close IN;     	        				#close filehandle
   #
   # generate HTML output
   #
   $bgcolor = "green"; 						#initialize variable
   foreach $key (keys %filesystems) {
      print "   checking mount status of $filesystems{$key}{mount_point} \n" if ($verbose eq "yes");
      $bgcolor = "red" if ( ($filesystems{$key}{auto_mount} eq "yes") && ($filesystems{$key}{mounted} ne "yes") );
   } 								#end of foreach loop
   if ($bgcolor eq "green") {
      print "<tr><td>filesystems <td bgcolor=green> OK <td> All filesystems mounted \n" 
   }                                                   		#end of if block
   if ($bgcolor eq "red") {
      print "<tr><td>filesystems <td bgcolor=red> WARNING <td>  \n" ;
      foreach $key (keys %filesystems) {
         print "<br> $filesystems{$key}{mount_point} is not mounted \n" if ( ($filesystems{$key}{auto_mount} eq "yes") && ($filesystems{$key}{mounted} ne "yes") );
      } 							#end of foreach loop
   }                                                   		#end of if block
}                                                     		#end of subroutine





sub check_disk_space {
   #
   print "running check_disk_space subroutine \n" if ($verbose eq "yes");
   #
   # show filesystem space utilization
   # command output will look similar to:
   #  # df -g
   # Filesystem    1024-blocks    Free %Used    Iused %Iused Mounted on
   # /dev/hd4          2097152    891168   58%    19910     9% /
   # /dev/hd2          4194304   1419900   67%    50160    14% /usr
   # /dev/hd9var       2097152   1846024   12%     2590     1% /var
   # /dev/hd3         11534336   8400912   28%      471     1% /tmp
   # /dev/hd1          4194304   1402696   67%      567     1% /home
   # /dev/hd11admin      131072    130692    1%        9     1% /admin
   # /proc                   -         -    -        -      - /proc
   # /dev/hd10opt      2097152   1382432   35%     8347     3% /opt
   # /dev/livedump      262144    261776    1%        4     1% /var/adm/ras/livedump
   # /dev/lvoradata    31424512   1923476   94%    40404     9% /oradata
   #  
   #
   #
   # generate HTML output
   #
   print "<tr><td>Disk space <td bgcolor=green> OK </td> \n";
   print "    <td>  \n";
   print "    <pre> \n";
   $cmd = "$df -g";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");						#open filehandle using command output
   while (<IN>) {                                       	#read a line from the filehandle
      print $_;
   }                   						#end of while loop
   close IN;     	        				#close filehandle
   print "    </pre> \n";
}                                                     		#end of subroutine




sub check_cpu {
   #
   print "running check_cpu subroutine \n" if ($verbose eq "yes");
   #
   # Check for high CPU utilization
   #
   # command output will look similar to:
   #   # iostat -t
   #   System configuration: lcpu=8 ent=0.20
   #   tty:      tin         tout    avg-cpu: % user % sys % idle % iowait physc % entc
   #             0.0          0.7                0.2   0.5   99.3      0.0   0.0    1.6
   #
   $checks{rootvg}{active} = ""; 				#initialize variable
   $cmd = "$iostat -t";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");						#open filehandle using command output
   while (<IN>) {                                       	#read a line from the filehandle
      next if (/^System configuration:/);					#skip header row
      next if (/^tty:/);					#skip header row
      if ( /^ +[0-9\.]+ +[0-9\.]+ +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+)/ ) {	#find cpu util
         $checks{cpu}{user}  = $1;				#assign value to hash element
         $checks{cpu}{sys}   = $2;				#assign value to hash element
         $checks{cpu}{idle}  = $3;				#assign value to hash element
         $checks{cpu}{wait}  = $4;				#assign value to hash element
         $checks{cpu}{physc} = $5;				#assign value to hash element
         $checks{cpu}{entc} =  $6;				#assign value to hash element
      } 							#end of if/elsif block
   }                   						#end of while loop
   close IN;     	        				#close filehandle
   #
   #
   # generate HTML output
   #
   print "<tr><td>CPU <td bgcolor=green>  OK      <td> CPU utilization is OK   \n" if ( $checks{cpu}{idle} >= 50 );
   print "<tr><td>CPU <td bgcolor=orange> WARNING <td> CPU utilization is high \n" if ( $checks{cpu}{idle} <  50 );
   print "<tr><td>CPU <td bgcolor=red>    WARNING <td> CPU utilization is high \n" if ( $checks{cpu}{idle} <  20 );
   print "<br>user $checks{cpu}{user}\% <br> sys $checks{cpu}{sys}\% <br> idle $checks{cpu}{idle}\% <br> wait $checks{cpu}{wait}\% <br>Physical CPU $checks{cpu}{physc} <br> Entitled Capacity $checks{cpu}{entc} \n" ;
}                                                     		#end of subroutine




sub check_paging_space {
   #
   print "running check_paging_space subroutine \n" if ($verbose eq "yes");
   #
   # Check paging space utilization
   #
   # command output will look similar to:
   #   # lsps -s
   # Total Paging Space   Percent Used
   #      8192MB               0%
   #             0.0          0.7                0.2   0.5   99.3      0.0   0.0    1.6
   #
   $checks{paging}{total_MB} = ""; 				#initialize variable
   $checks{paging}{pct_used} = ""; 				#initialize variable
   $cmd = "$lsps -s";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");						#open filehandle using command output
   while (<IN>) {                                       	#read a line from the filehandle
      next if (/^Total Paging Space/);				#skip header row
      if ( /^ +([0-9]+)MB +([0-9]+)\%/ ) {			#find paging space usage
         $checks{paging}{total_MB}  = $1;			#assign value to hash element
         $checks{paging}{pct_used}  = $2;			#assign value to hash element
      } 							#end of if/elsif block
   }                   						#end of while loop
   close IN;     	        				#close filehandle
   #
   #
   # generate HTML output
   #
   print "<tr><td>Paging Space <td bgcolor=green>  OK      <td> Paging space usage is OK   \n" if ( $checks{paging}{pct_used} <  50 );
   print "<tr><td>CPU <td bgcolor=orange> WARNING <td> Paging space usage is high \n" if ( $checks{paging}{pct_used} >= 50 );
   print "<tr><td>CPU <td bgcolor=red>    WARNING <td> Paging space usage is high \n" if ( $checks{paging}{pct_used} >= 75 );
   print "<br>Paging space total: $checks{paging}{total_MB}MB  <br>Percent used: $checks{paging}{pct_used} \n" ;
}                                                     		#end of subroutine



sub print_html_footer {
   #
   print "running print_html_footer subroutine \n" if ($verbose eq "yes");
   #
   # print HTML closing tags 
   print "</body></html> \n";
}                                                                       #end of subroutine







# ----------------- main body of script --------------------------
sanity_checks;
print_html_header;
check_hostname;
check_oslevel;
check_sshd;
check_processes;
check_dns;
check_ntp;
check_default_route;
check_errpt;
check_sendmail_queue;
check_mailboxes;
check_print_queue;
check_loopback;
check_syslog;
check_wtmp;
check_system_attention_light;
check_tsm_client;
check_sysdumpdev;
check_nfs_source_port;
check_rclocal;
check_rctcpip;
check_volume_groups;
check_filesystems;
check_disk_space;
check_cpu;
check_paging_space;
print_html_footer;
