#!/usr/bin/perl -w

# script to record AIX performance metrics in RRD file
# graphs are generated client-side using javascript-enabled web browser


# CHANGE LOG
# ----------
#  2016/03/26	njeffrey	Script created
#  2016/03/31	njeffrey	switch from rrdtool binary to RRD::Editor perl module
#  2016/04/09	njeffrey	add error checks
#  2016/04/10	njeffrey	export RRD values to CSV files for graphing with javascript based dygraphs from www.dygraphs.com
#  2016/04/14	njeffrey	add --rrdinfo and --xmldump parameters
#  2016/05/17	njeffrey	add "use POSIX" to validate operating system is AIX





# OUTSTANDING TASKS
# -----------------
# only recreate daily graphs every 4 hours, weekly graphs every day, etc
# add subroutine get_filesystem_usage to create RRD files for any and all filesystems 
# document how to install the RRD::Editor perl module   perl -MCPAN -e 'install RRD::Editor'
# write README.txt explaining how to use
# write INSTALL.txt explaining how to install
# add httpd.pl as a dependency
# write install.sh script
# get_disk_latency subroutine is not yet saving to an RRD file - need to figure out how to create RRD if disk names may change over time
# instead of calling vmstat/iostat/lsps, see if you can pull all of this data out of an nmon file that is constantly running




# NOTES
# ------
# It is assumed that this script is run every 5 minutes from cron by the arrdvark user.  Example:
#   0,5,10,15,20,25,30,35,40,45,50,55 * * * * /usr/local/arrdvark/arrdvark.pl >/dev/null 2>&1  #generate RRD performance metrics
#
# This script will keep 1 year of CSV data, and automatically truncate data older than 1 year.



# TROUBLESHOOTING
# ---------------
# If you get this error:  Can't locate RRD/Editor.pm
# You will need to install the RRD::Editor per module with: perl -m CPAN "install RRD::Editor"



use strict;						#enforce good coding practices
use Getopt::Long;                                       #allow --long-switches to be used as parameters
use POSIX; 						#core perl module that emulates uname command
use RRD::Editor ();					#use external perl module - install with: perl -m CPAN 'install RRD::Editor' 


#declare variables
my ($cmd,$vmstat,$lsps,$iostat,$rrd);
my ($memTotal,$memComp,$memNoncomp,$memFree);
my ($pagespaceTotal,$pagespaceUsed,$pagingIn,$pagingOut);
my ($cpuSys,$cpuUser,$cpuIdle,$cpuWait,$cpuPhysical,$cpuEntitled,$cpuEntitled_pct);
my ($output_file,$output_dir,$verbose,$version);
my ($opt_h,$opt_v,$opt_V,$opt_i,$opt_d);
my ($common_switches);
my ($black,$white,$red,$orange,$green,$blue,$purple,$yellow);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst,$seconds_since_epoch,$i);
my ($key,%csvdata,$fileext);
my (%disks,$hdisk,$iops,$read_latency,$write_latency);
my ($start,$end,$resolution);
$vmstat      = "/usr/bin/vmstat";
$lsps        = "/usr/sbin/lsps";
$iostat      = "/usr/bin/iostat";
$output_file = "/usr/local/arrdvark/arrdvark";
$output_dir  = "/usr/local/arrdvark";
$version     = "20160517";				#last update to script in yyyymmdd format
$i           = ""; 					#counter variable used in for loops




sub get_options {
   #
   # this gets the command line parameters provided by the users
   #
   #
   Getopt::Long::Configure('bundling');
   GetOptions(
      "h"   => \$opt_h, "help"     => \$opt_h,
      "v"   => \$opt_v, "verbose"  => \$opt_v,
      "V"   => \$opt_V, "version"  => \$opt_V,
      "i"   => \$opt_i, "rrdinfo"  => \$opt_i,
      "d"   => \$opt_d, "xmldump"  => \$opt_d,
   );
   #
   #
   #
   # If the user supplied -h or --help, generate the help messages
   #
   if( defined( $opt_h ) ) {
      print "Script to save AIX physical memory usage statistics in a CSV file  \n";
      print "Examples: $0           \n";
      print "          $0 --verbose    (verbose output for debugging)     \n";
      print "          $0 --version    (show version number)              \n";
      print "          $0 --rrdinfo    (show details about the .rrd file) \n";
      print "          $0 --xmldump    (dump rrd file to xml)             \n";
      print "          $0 --help       (this output)                      \n";
      print "\n\n";
      exit;
   }
   #
   #
   # If the user supplied -v or --verbose, generate more verbose output for debugging
   #
   if( defined( $opt_v ) ) {
      $verbose = "yes";
   } else {
      $verbose = "no";
   }
   #
   #
   # If the user supplied -V or --version, print the version number
   #
   if( defined( $opt_V ) ) {
      print "$0 version $version \n";
      exit;
   }
   #
   #
   # If the user supplied --rrdinfo, show info about the .rrd file
   #
   if( defined( $opt_i ) ) {
      if (! -e "$output_file.rrd" ) {
         print "   ERROR: $output_file.rrd does not exist \n";
         exit;
      } 							#end of if block
      if ( -e "$output_file.rrd" ) {				#confirm the .rrd file exists
         $rrd = RRD::Editor->new();				#create a new object
         $rrd->open("$output_file.rrd");			#open the RRD file
         print $rrd->info();					#show information about the RRD file
         $rrd->close();						#close object
         exit;							#exit script
      } 							#end of if block
   } 								#end of if block
   #
   #
   # If the user supplied --xmldump, dump the rrd contents to XML
   #
   if( defined( $opt_d ) ) {
      if (! -e "$output_file.rrd" ) {
         print "   ERROR: $output_file.rrd does not exist \n";
         exit;
      } 							#end of if block
      if ( -e "$output_file.rrd" ) {				#confirm the .rrd file exists
         $rrd = RRD::Editor->new();				#create a new object
         $rrd->open("$output_file.rrd");			#open the RRD file
         print $rrd->dump();					#show information about the RRD file
         $rrd->close();						#close object
         exit;							#exit script
      } 							#end of if block
   } 								#end of if block
}                                                               #end of subroutine





sub sanity_checks {
   #
   print "running sanity_checks subroutine \n" if ($verbose eq "yes");
   #
   $_ = $vmstat; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsps; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $iostat; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   #
   # confirm system is running AIX
   my ($sysname, $nodename, $release, $version, $machine) = POSIX::uname();
   unless ( $sysname =~ /AIX/) {
      print "ERROR: This script only runs on AIX.  Current system is $sysname \n";
      exit;
   } 							#end of unless block
} 							#end of subroutine






sub get_date {
   #
   print "running get_date subroutine \n" if ($verbose eq "yes");
   #
   ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   $year = $year + 1900;                                #$year is number of years since 1900
   $mon  = $mon + 1;                                    #$mon starts counting at 0
   $mon  = "0$mon"  if ($mon  < 10);                    #add leading zero if required
   $mday = "0$mday" if ($mday < 10);                    #add leading zero if required
   $hour = "0$hour" if ($hour < 10);                    #add leading zero if required
   $min  = "0$min"  if ($min  < 10);                    #add leading zero if required
   $sec  = "0$sec"  if ($sec  < 10);                    #add leading zero if required
   #
   $seconds_since_epoch = time();
   #
   print "   current time: $year-$mon-$mday $hour:$min:$sec \n" if ($verbose eq "yes");
   print "   seconds since epoch: $seconds_since_epoch      \n" if ($verbose eq "yes");
}                                                       #end of subroutine



sub get_memory_util {
   #
   print "running get_memory_util subroutine \n" if ($verbose eq "yes");
   #
   #
   # Initialize variables so we can perform addition/division for averaging
   $memTotal        = 0;
   $memFree         = 0;
   $memComp         = 0;
   $memNoncomp      = 0;
   #
   #
   # Get physical memory utilization
   #
   $cmd = "$vmstat -v"; 					#command to be run
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open(IN,"$cmd|");                                    	#open a filehandle using command output
   while (<IN>) {                                       	#read a line from STDIN
      if ( /([0-9\.]+) +memory pages/ ) {               	#find the vmstat output that shows number of memory pages
         $memTotal = $1;                  	             	#assign to variable
         $memTotal= $memTotal * 4096;                		#multiply memory pages by 4096 to get bytes of memory
         $memTotal = sprintf( "%.2f", $memTotal);	     	#truncate to 2 decimal place
      }                                                 	#end of if block
      if ( /([0-9\.]+) +free pages/ ) {                 	#find the vmstat output that shows number of free memory pages
         $memFree  = $1;                               		#assign to variable
         $memFree  = $memFree * 4096;                 		#multiply memory pages by 4096 to get bytes of memory
         $memFree  = sprintf( "%.2f", $memFree);     	 	#truncate to 1 decimal place
      }                                                 	#end of if block
      if ( /([0-9\.]+) +numclient percentage/ ) {       	#find the percentage of memory used by client paging (filesystem cache)
         $memNoncomp = $1;                                 	#assign to variable
         $memNoncomp = $memNoncomp * $memTotal / 100;  		#convert percentage used to Gigabytes used by filesystem cache
         $memNoncomp = sprintf( "%.2f", $memNoncomp);   	#truncate to 1 decimal place
      }                                                 	#end of if block
      if ( /([0-9\.]+) +percentage of memory used for computational pages/ ) {     #find the percentage of memory used by computational pages
         $memComp = $1;                                	#assign to variable
         $memComp = $memComp * $memTotal / 100;      	#convert percentage used to Gigabytes used by filesystem cache
         $memComp = sprintf( "%.2f", $memComp);       	#truncate to 1 decimal place
      }                                                 	#end of if block
   }                                                    	#end of while loop
   close IN;                                            	#close filehandle
   print "   Total memory:$memTotal, Free memory:$memFree, Computational Memory:$memComp, Filesystem Cache:$memNoncomp \n" if ($verbose eq "yes");
   #
   #

}                                                       #end of subroutine




sub get_pagingspace_util {
   #
   print "running get_pagingspace_util subroutine \n" if ($verbose eq "yes");
   #
   #
   # Initialize variables so we can perform addition/division for averaging
   $pagespaceTotal  = 0;
   $pagespaceUsed   = 0;
   #
   # Get paging space utilization
   #
   # You will get command output similar to the following:
   #   lsps -s
   #   Total Paging Space   Percent Used
   #    10752MB               0%
   #
   $cmd = "$lsps -s"; 							#command to be run
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open(IN,"$cmd|");                                    		#open a filehandle using command output
   while (<IN>) {                                       		#read a line from STDIN
      if ( /([0-9]+)MB +([0-9]+)\%/ ) {               			#find the command output that shows paging space size and utilization
         $pagespaceTotal = $1;            				#assign to variable
         $pagespaceTotal = $pagespaceTotal * 1024 * 1024;  		#convert from megabytes to bytes
         $pagespaceUsed = $2;            				#assign to variable
         $pagespaceUsed  = $pagespaceTotal * $pagespaceUsed / 100; 	#convert from percentage to bytes
      }                                                 		#end of if block
   }                                                    		#end of while loop
   close IN;                                            		#close filehandle
   print "   Total paging space:$pagespaceTotal bytes, Used:$pagespaceUsed bytes\n" if ($verbose eq "yes");
}                                                       #end of subroutine






sub get_cpu_and_paging {
   #
   print "running get_cpu_and_paging subroutine \n" if ($verbose eq "yes");
   #
   #
   # Initialize variables so we can perform addition/division for averaging
   $pagingIn        = 0;
   $pagingOut       = 0;
   $cpuUser         = 0;
   $cpuSys          = 0;
   $cpuIdle         = 0;
   $cpuWait         = 0;
   $cpuPhysical     = 0;
   $cpuEntitled     = 0;
   $cpuEntitled_pct = 0;
   #
   #
   # Get paging in/out activity and CPU utilization from vmstat (same command gives us a two-for-one)
   #
   # You will get command output similar to the following.
   # The interesting colums are:  pi=pages in from paging space, po=pages out to paging space
   #  # vmstat 1 10
   #  
   #  System configuration: lcpu=8 mem=2048MB ent=0.20
   #
   #  kthr    memory              page              faults              cpu
   #  ----- ----------- ------------------------ ------------ -----------------------
   #   r  b   avm   fre  re  pi  po  fr   sr  cy  in   sy  cs us sy id wa    pc    ec
   #   2  0 393884 91900   0   0   0   0    0   0 104 4201 515 40  9 51  0  0.16  81.2
   #   0  0 392699 93085   0   0   0   0    0   0  82 4799 477 20 12 69  0  0.10  51.7
   #   0  0 393861 91921   0   0   0   0    0   0  47 3632 476 22 11 68  0  0.10  48.9
   #   0  0 394992 90788   0   0   0   0    0   0  70 5275 499 29 10 61  0  0.12  58.8
   #   0  0 392775 93005   0   0   0   0    0   0  55 5621 524 49 10 42  0  0.25 127.5
   #   0  0 392634 93146   0   0   0   0    0   0  58  368 428  1  2 97  0  0.01   6.3
   #   0  0 393910 91868   0   0   0   0    0   0  77 3883 457 26 10 64  0  0.12  58.3
   #   0  0 393176 92601   0   0   0   0    0   0  65 2033 459 16  7 77  0  0.08  38.2
   #   0  0 395905 89874   0   0   0   0    0   0 171 9065 703 48 23 29  0  0.20  97.7
   #   3  0 394725 91039   0   0   0   0    0   0 416 42773 1459 73 15 12  0  0.85 422.5
   #
   #
   $cmd = "$vmstat 1 10"; 						#command to be run
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open(IN,"$cmd|");                                    		#open a filehandle using command output
   while (<IN>) {                                       		#read a line from STDIN
      #
      #find the command output that shows paging activity
      if ( /^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +([0-9]+) +([0-9]+) / ) {  	
         $pagingIn  = $pagingIn  + $1; 					#running total of paging activity
         $pagingOut = $pagingOut + $2;  	       			#running total of  paging activity
      }                                                 		#end of if block
      #
      #find the command output that shows CPU percentage used (columns us sy id wa)
      if ( /^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+)/ ) {  
         $cpuUser = $cpuUser + $1;           				#assign to variable
         $cpuSys  = $cpuSys  + $2;           				#assign to variable
         $cpuIdle = $cpuIdle + $3;           				#assign to variable
         $cpuWait = $cpuWait + $4; 		    			#assign to variable
      }                                                 		#end of if block
      #
      #find the command output that shows physical CPU consumed and %entitled capacity (columns pc ec)
      #these values will only exist if this is an LPAR (Logical PARtition)
      if ( /^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +([0-9\.]+) +([0-9\.]+)/ ) {  
         $cpuPhysical     = $cpuPhysical     + $1;			#assign to variable
         $cpuEntitled_pct = $cpuEntitled_pct + $2;			#assign to variable (although we never actually use this value)
      }                                                 		#end of if block
      #
      #find the command output that shows entitled capacity for the LPAR
      #this value will only exist if this is an LPAR (Logical PARtition)
      #We could calculate this value from the %entitled column in the vmstat output, 
      #but the calculation will be inaccurate because vmstat only shows 2 decimal places.
      #  System configuration: lcpu=8 mem=2048MB ent=0.20
      if ( /System configuration: lcpu=[0-9]+ mem=[0-9]+MB ent=([0-9\.]+)/ ) {  
         $cpuEntitled = $1;						#assign to variable
      }                                                 		#end of if block
   }                                                    		#end of while loop
   close IN;                                            		#close filehandle
   #
   #
   # At this point, we have 10 data points for paging activity and CPU usage.
   # Figure out the average of those data points.
   $pagingIn        = $pagingIn * 4096;  				#multiply by number of 4096 byte memory pages to get bytes 
   $pagingIn        = $pagingIn / 10; 					#get average of 10 data points from vmstat
   $pagingIn        = sprintf( "%.0f", $pagingIn);     			#truncate to 0 decimal place
   $pagingOut       = $pagingOut * 4096;  				#multiply by number of 4096 byte memory pages to get bytes 
   $pagingOut       = $pagingOut / 10; 					#get average of 10 data points from vmstat
   $pagingOut       = sprintf( "%.0f", $pagingOut);     		#truncate to 0 decimal place
   $cpuUser         = $cpuUser / 10; 					#get average of 10 data points from vmstat
   $cpuUser         = sprintf( "%.1f", $cpuUser);     			#truncate to 1 decimal place
   $cpuSys          = $cpuSys / 10; 					#get average of 10 data points from vmstat
   $cpuSys          = sprintf( "%.1f", $cpuSys);	     		#truncate to 1 decimal place
   $cpuIdle         = $cpuIdle / 10; 					#get average of 10 data points from vmstat
   $cpuIdle         = sprintf( "%.1f", $cpuIdle);     			#truncate to 1 decimal place
   $cpuWait         = $cpuWait / 10; 					#get average of 10 data points from vmstat
   $cpuWait         = sprintf( "%.1f", $cpuWait);	     		#truncate to 1 decimal place
   $cpuPhysical     = $cpuPhysical / 10; 				#get average of 10 data points from vmstat
   $cpuPhysical     = sprintf( "%.2f", $cpuPhysical);	     		#truncate to 2 decimal places
   $cpuEntitled_pct = $cpuEntitled_pct / 10; 				#get average of 10 data points from vmstat
   $cpuEntitled_pct = sprintf( "%.2f", $cpuEntitled_pct);     		#truncate to 2 decimal places
   #
   print "   Paging activity  in:$pagingIn bytes   out:$pagingOut bytes \n" if ($verbose eq "yes");
   print "   CPU user:$cpuUser\% system:$cpuSys\% idle:$cpuIdle\% wait:$cpuWait\% physical:$cpuPhysical entitled:$cpuEntitled \n" if ($verbose eq "yes");
} 									#end of subroutine




sub get_disk_latency {
   #
   print "running get_disk_latency subroutine \n" if ($verbose eq "yes");
   #
   #
   # You will get command output similar to the following:
   #   iostat -DRTl 1 10
   #
   # Disks:                     xfers                                read                                write                                  queue                    time
   # -------------- -------------------------------- ------------------------------------ ------------------------------------ -------------------------------------- ---------
   #                  %tm    bps   tps  bread  bwrtn   rps    avg    min    max time fail   wps    avg    min    max time fail    avg    min    max   avg   avg  serv
   #                  act                                    serv   serv   serv outs              serv   serv   serv outs        time   time   time  wqsz  sqsz qfull
   #
   # hdisk0           0.0   0.0    0.0   0.0    0.0    0.0   0.0    0.0    0.0     0    0   0.0   0.0    0.0    0.0     0    0   0.0    0.0    0.0    0.0   0.0   0.0  11:44:31
   # hdisk1          60.0 169.1M 645.0 169.1M   0.0  645.0   0.9    0.7    1.5     0    0   0.0   0.0    0.0    0.0     0    0   0.0    0.0    0.0    0.0   0.0   0.0  11:44:31
   #
   # hdisk0           0.0   0.0    0.0   0.0    0.0    0.0   0.0    0.0    0.0     0    0   0.0   0.0    0.0    0.0     0    0   0.0    0.0    0.0    0.0   0.0   0.0  11:44:32
   # hdisk1          79.0 164.1M 626.0 164.1M   0.0  626.0   1.3    0.7   34.0     0    0   0.0   0.0    0.0    0.0     0    0   0.0    0.0    0.0    0.0   0.0   0.0  11:44:32
   #
   # This is what each of the fields mean:
   # %tm act:     percent of time the device was active (we can see if disk load is balanced correctly or not, 1 used heavily others not)
   # bps:         amount of data transferred (read or written) per second (default is in bytes per second)
   # tps:         number of transfers per second
   #             (Transfer is an I/O request, and multiple logical requests can be combined into 1 I/O request with different size)
   # bread:       amount of data read per second (default is in bytes per second)
   # bwrtn:       amount of data written per second (default is in bytes per second)
   # rps:         number of read transfers per second.
   # avgserv:     average service time per read transfer (default is in milliseconds)
   # minserv:     minimum service time per read transfer (default is in milliseconds)
   # maxserv:     maximum service time per read transfer (default is in milliseconds)
   # timeouts:    number of read/write timeouts per second
   # fail:        number of failed read/write requests per second
   # wps:         number of write transfers per second.
   # avgserv:     average service time per write transfer (default is in milliseconds)
   # minserv:     minimum service time per write transfer (default is in milliseconds)
   # maxserv:     maximum service time per write transfer (default is in milliseconds)
   # timeouts:    number of read/write timeouts per second
   # fail:        number of failed read/write requests per second
   # avgtime:     average time spent in the wait queue (waiting to get sent to the disk, the disk's queue is full) (default is in milliseconds)
   # mintime:     minimum time spent in the wait queue (waiting to get sent to the disk, the disk's queue is full) (default is in milliseconds)
   # maxtime:     maximum time spent in the wait queue (waiting to get sent to the disk, the disk's queue is full) (default is in milliseconds)
   # avgwqsz:     average wait queue size (waiting to be sent to the disk)
   # avgsqsz:     average service queue size (this can't exceed queue_depth for the disk)
   # sqfull:      number of times the service queue becomes full per second (that is, the disk is not accepting any more service requests)
   #
   #
   # 

   #
   $cmd = "$iostat -DRTl 1 10"; 					#command to be run
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open(IN,"$cmd|");                                    		#open a filehandle using command output
   while (<IN>) {                                       		#read a line from STDIN
      if ( /^hdisk/ ) { 						#find the iostat output that begins with hdisk
         s/ +/ /g; 							#collapse multiple spaces into a single space
         ($hdisk, $iops, $read_latency, $write_latency) = (split / /, $_)[0,3,7,13];	#retrieve element 0,3,7,13 from split
         print "   hdisk:$hdisk iops:$iops ReadLatency:$read_latency WriteLatency:$write_latency \n" if ($verbose eq "yes");
         #
         # initialize hash elements if required (so we can perform addition)
         $disks{$hdisk}{hdisk}         = $hdisk;
         $disks{$hdisk}{iops}          = 0 unless ( defined $disks{$hdisk}{iops}          );	
         $disks{$hdisk}{read_latency}  = 0 unless ( defined $disks{$hdisk}{read_latency}  );	
         $disks{$hdisk}{write_latency} = 0 unless ( defined $disks{$hdisk}{write_latency} );
         #
         # ensure consistent units are used (K=kilo M=mega G=giga S=seconds)
         if ($iops =~ /K/) {						#check for units in Kilo
            $iops =~ s/K//g;						#remove unit signifier
            $iops = $iops * 1000;					#multiply to remove unit
         }
         if ($iops =~ /M/) {						#check for units in Mega
            $iops =~ s/M//g;						#remove unit signifier
            $iops = $iops * 1000 * 1000;				#multiply to remove unit
         }
         if ($iops =~ /G/) {						#check for units in Giga
            $iops =~ s/G//g;						#remove unit signifier
            $iops = $iops * 1000 * 1000 * 1000;				#multiply to remove unit
         }
         if ($read_latency =~ /S/) {					#check for units in seconds instead of milliseconds
            $read_latency =~ s/S//g;					#remove unit signifier
            $read_latency = $read_latency * 1000;			#multiply to remove unit
         }
         if ($write_latency =~ /S/) {					#check for units in seconds instead of milliseconds
            $write_latency =~ s/S//g;					#remove unit signifier
            $write_latency = $write_latency * 1000;			#multiply to remove unit
         }
         #
         # save running totals 
         $disks{$hdisk}{iops}          = $disks{$hdisk}{iops}          + $iops;		 
         $disks{$hdisk}{read_latency}  = $disks{$hdisk}{read_latency}  + $read_latency;	 
         $disks{$hdisk}{write_latency} = $disks{$hdisk}{write_latency} + $write_latency;	 
      }                                                 		#end of if block
   }                                                    		#end of while loop
   close IN;                                            		#close filehandle
   #
   # calculate averages from running totals
   foreach $key (sort keys %disks) {
      if ($disks{$key}{iops} > 0) {							#avoid divide by zero errors
         $disks{$key}{iops}          = $disks{$key}{iops} / 10;				#get average of 10 data points from iostat 
         $disks{$key}{iops}          = sprintf( "%.0f", $disks{$key}{iops});   		#truncate to 0 decimal places
      }
      if ($disks{$key}{read_latency} > 0) {						#avoid divide by zero errors
         $disks{$key}{read_latency}  = $disks{$key}{read_latency} / 10; 		#get average of 10 data points from iostat
         $disks{$key}{read_latency}  = sprintf( "%.1f", $disks{$key}{read_latency});    #truncate to 0 decimal places
      }
      if ($disks{$key}{write_latency} > 0) {						#avoid divide by zero errors
         $disks{$key}{write_latency} = $disks{$key}{write_latency} / 10; 		#get average of 10 data points from iostat
         $disks{$key}{write_latency} = sprintf( "%.1f", $disks{$key}{write_latency});   #truncate to 0 decimal places
      }
      print "   $disks{$key}{hdisk} IOPS:$disks{$key}{iops}, ReadLatency:$disks{$key}{read_latency}, WriteLatency:$disks{$key}{write_latency} \n" if ($verbose eq "yes");
   } 									# end of foreach block
}                                                       #end of subroutine




sub create_rrd {
   #
   print "running create_rrd subroutine \n" if ($verbose eq "yes");
   #
   # Note that the DS names can be a maximum of 19 alphanumeric characters.  No special characters like .-_\/|!@#
   #
   # The RRD file will contain four different RRA (Round Robin Archives)
   # 1 day   at 5 minute resolution   RRA:AVERAGE:0.5:1:288       86400 seconds [1 day] / 300 seconds [5 minutes] = 288 rows
   # 1 week  at 15 minute resolution  RRA:AVERAGE:0.5:3:672       1 week [ = 604800 seconds ] in 15 minutes [ = 900 seconds ] = 604800/900 = 672 rows
   # 1 month at 1 hour resolution     RRA:AVERAGE:0.5:12:744
   # 1 year  at 6 hour resolution     RRA:AVERAGE:0.5:72:1480
   #
   #
   if ( -e "$output_file.rrd" )	 {			#break out of subroutine if RRD file already exists
      print "   $output_file.rrd already exists \n" if ($verbose eq "yes");
   } 							#end of if block
   if ( ! -e "$output_file.rrd" ) {
      print "   creating RRD file $output_file.rrd \n" if ($verbose eq "yes");
      $rrd = RRD::Editor->new();				#create a new object
      $rrd->create("--format portable-double
                    --step 300
                    --start $seconds_since_epoch
                    DS:memTotal:GAUGE:600:U:U 
                    DS:memComp:GAUGE:600:U:U 
                    DS:memNoncomp:GAUGE:600:U:U 
                    DS:memFree:GAUGE:600:U:U 
                    DS:pagespaceTotal:GAUGE:600:U:U 
                    DS:pagespaceUsed:GAUGE:600:U:U 
                    DS:pagingIn:GAUGE:600:U:U 
                    DS:pagingOut:GAUGE:600:U:U 
                    DS:cpuUser:GAUGE:600:U:U 
                    DS:cpuSys:GAUGE:600:U:U 
                    DS:cpuIdle:GAUGE:600:U:U 
                    DS:cpuWait:GAUGE:600:U:U 
                    DS:cpuPhysical:GAUGE:600:U:U 
                    DS:cpuEntitled:GAUGE:600:U:U 
                    RRA:AVERAGE:0.5:1:288 
                    RRA:AVERAGE:0.5:3:672 
                    RRA:AVERAGE:0.5:12:744 
                    RRA:AVERAGE:0.5:72:1480
                   "); 					#create RRD
      $rrd->save("$output_file.rrd","portable-double"); #save RRD to file (using portable-double format)
      $rrd->close(); 					#close object
   } 							#end of if block
   #
   # confirm .rrd file was created
   if ( ! -e "$output_file.rrd" ) {
      print "   ERROR: Could not create $output_file.rrd - please check file permissions \n";
   } 							#end of if block
   #
   # confirm .rrd file has write permissions
   if ( ! -w "$output_file.rrd" ) {
      print "   ERROR: $output_file.rrd is not writeable by the current user - please check file permissions \n";
   } 							#end of if block

} 							#end of subroutine






sub update_rrd {
   #
   print "running update_rrd subroutine \n" if ($verbose eq "yes");
   #
   #
   print "   Adding these values to RRD file  seconds_since_epoch:memTotal:memComp:memNoncomp:memFree:pagespaceTotal:pagespaceUsed:pagingIn:pagingOut:cpuUser:cpuSys:cpuIdle:cpuWait:cpuPhysical:cpuEntitled \n" if ($verbose eq "yes");
   print "   Adding these values to RRD file  $seconds_since_epoch:$memTotal:$memComp:$memNoncomp:$memFree:$pagespaceTotal:$pagespaceUsed:$pagingIn:$pagingOut:$cpuUser:$cpuSys:$cpuIdle:$cpuWait:$cpuPhysical:$cpuEntitled \n" if ($verbose eq "yes");
   #
   if ( ! -e "$output_file.rrd" ) {			#warn if rrd file does not exist
      print "ERROR: Cannot find RRD file $output_file.rrd \n";
      exit;						#exit script
   } 							#end of if block
   if ( ! -w "$output_file.rrd" ) {			#warn if rrd file is not writeable by the current user
      print "ERROR: Cannot write to RRD file $output_file.rrd - please check file permissions. \n";
      print "       $output_file.rrd should be owned by arrdvark user. \n";
      exit;						#exit script
   } 							#end of if block
   $rrd = RRD::Editor->new();				#create a new object
   $rrd->open("$output_file.rrd");			#open the RRD file
   $rrd->update("$seconds_since_epoch:$memTotal:$memComp:$memNoncomp:$memFree:$pagespaceTotal:$pagespaceUsed:$pagingIn:$pagingOut:$cpuUser:$cpuSys:$cpuIdle:$cpuWait:$cpuPhysical:$cpuEntitled"); #add data to the RRD file
   $rrd->save(); 					#save updates to disk
   $rrd->close(); 					#close object
} 							#end of subroutine







sub export_rrd_to_csv {
   #
   print "running export_to_csv subroutine \n" if ($verbose eq "yes");
   #
   # This subroutine is called by the following other subroutines:
   #   create_daily_csv  create_weekly_csv  create_monthly_csv  create_yearly_csv
   #
   # output from rrd->fetch will be similar to:
   #             memTotal         memComp          memNoncomp       memFree          pagespaceTotal   pagespaceUsed    pagingIn         pagingOut        cpuUser          cpuSys           cpuIdle          cpuWait          cpuPhysical      cpuEntitled
   #1460666400: 2.1474836480e+09 1.4624363643e+09 7.5376676045e+08 7.4489856000e+07 5.3687091200e+08 1.0737418240e+07 0.0000000000e+00 0.0000000000e+00 4.8000000000e+00 3.6000000000e+00 9.1500000000e+01 0.0000000000e+00 4.0000000000e-02 1.7400000000e+01
   #1460666700: 2.1474836480e+09 1.4624363643e+09 7.5376676045e+08 7.4510336000e+07 5.3687091200e+08 1.0737418240e+07 0.0000000000e+00 0.0000000000e+00 4.8000000000e+00 3.5000000000e+00 9.1300000000e+01 0.0000000000e+00 4.0000000000e-02 1.7640000000e+01
   #
   #
   $rrd = RRD::Editor->new();				#create a new object
   $rrd->open("$output_file.rrd");			#open the RRD file
   #
   $_ = $rrd->fetch("AVERAGE --resolution $resolution --start $start --end $end --align-start");	#returns a multiline string
   @_ = split "\n",$_;					#split multiline string into array elements
   print "   there are $#_ elements in the array \n" if ($verbose eq "yes");
   foreach (@_) {					#loop through the output
      next unless (/[0-9]/);				#skip header rows that do not contain numbers
      s/: /,/g;						#change the colon+space to a comma
      s/ +/,/g;						#change spaces to commas
      next if (/,nan,/);				#skip lines that contain "nan" (means unavailable or unknown value)
      print $_ if ($verbose eq "yes");
      if (/([0-9]+),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),/) { 
         print "made it into regexp \n" if ($verbose eq "yes");
         $seconds_since_epoch = $1;			#assign to variable
         $memTotal            = sprintf ("%.0f",$2 );	#convert from scientific notation 4.3294573932+e10 to integer
         $memComp             = sprintf ("%.0f",$3 );   #convert from scientific notation to integer
         $memNoncomp          = sprintf ("%.0f",$4 );   #convert from scientific notation to integer
         $memFree             = sprintf ("%.0f",$5 );   #convert from scientific notation to integer
         $pagespaceTotal      = sprintf ("%.0f",$6 );   #convert from scientific notation to integer
         $pagespaceUsed       = sprintf ("%.0f",$7 );   #convert from scientific notation to integer
         $pagingIn            = sprintf ("%.0f",$9 );   #convert from scientific notation to integer
         $pagingOut           = sprintf ("%.0f",$9 );   #convert from scientific notation to integer
         $cpuSys              = sprintf ("%.2f",$10);   #convert from scientific notation to floating point
         $cpuUser             = sprintf ("%.2f",$11);   #convert from scientific notation to floating point
         $cpuIdle             = sprintf ("%.2f",$12);   #convert from scientific notation to floating point
         $cpuWait             = sprintf ("%.2f",$13);   #convert from scientific notation to floating point
         $cpuPhysical         = sprintf ("%.2f",$14);   #convert from scientific notation to floating point
         $cpuEntitled         = sprintf ("%.2f",$15);   #convert from scientific notation to floating point
         #
         # create a hash containing all the data, using the datestamp as the hash key
         $csvdata{$seconds_since_epoch}{seconds_since_epoch}      = $seconds_since_epoch;
         $csvdata{$seconds_since_epoch}{milliseconds_since_epoch} = $seconds_since_epoch * 1000;
         $csvdata{$seconds_since_epoch}{memTotal}                 = $memTotal;
         $csvdata{$seconds_since_epoch}{memComp}                  = $memComp;
         $csvdata{$seconds_since_epoch}{memNoncomp}               = $memNoncomp;
         $csvdata{$seconds_since_epoch}{memFree}                  = $memFree;
         $csvdata{$seconds_since_epoch}{pagespaceTotal}           = $pagespaceTotal;
         $csvdata{$seconds_since_epoch}{pagespaceUsed}            = $pagespaceUsed;
         $csvdata{$seconds_since_epoch}{pagingIn}                 = $pagingIn;
         $csvdata{$seconds_since_epoch}{pagingOut}                = $pagingOut;
         $csvdata{$seconds_since_epoch}{cpuSys}                   = $cpuSys;
         $csvdata{$seconds_since_epoch}{cpuUser}                  = $cpuUser;
         $csvdata{$seconds_since_epoch}{cpuIdle}                  = $cpuIdle;
         $csvdata{$seconds_since_epoch}{cpuWait}                  = $cpuWait;
         $csvdata{$seconds_since_epoch}{cpuPhysical}              = $cpuPhysical;
         $csvdata{$seconds_since_epoch}{cpuEntitled}              = $cpuEntitled;
      }							#end of if block
   } 							#end of foreach loop
   #
   # create CSV file with memory info
   open (OUT,">$output_dir/memory-$fileext.csv") or die "Cannot open $output_dir/memory-$fileext.csv for writing $! \n";
   print OUT "Date,memFree,memNoncomp,memComp\n";
   foreach $key (sort keys %csvdata) {
      print OUT "$csvdata{$key}{seconds_since_epoch},";	
      print OUT "$csvdata{$key}{memFree},";	
      print OUT "$csvdata{$key}{memNoncomp},";	
      print OUT "$csvdata{$key}{memComp}";		#no trailing comma for the last field
      print OUT "\n";
   } 							#end of foreach loop
   close OUT;						#close filehandle
   #
   # create CSV file with logical cpu info
   open (OUT,">$output_dir/cpu-$fileext.csv") or die "Cannot open $output_dir/cpu-$fileext.csv for writing $! \n";
   print OUT "Date,cpuWait,cpuIdle,cpuUser,cpuSys\n";
   foreach $key (sort keys %csvdata) {
      print OUT "$csvdata{$key}{seconds_since_epoch},";	
      print OUT "$csvdata{$key}{cpuWait},";	
      print OUT "$csvdata{$key}{cpuIdle},";	
      print OUT "$csvdata{$key}{cpuUser},";	
      print OUT "$csvdata{$key}{cpuSys}";		#no trailing comma for the last field
      print OUT "\n";
   } 							#end of foreach loop
   close OUT;						#close filehandle
   #
   # create CSV file with physical cpu info
   open (OUT,">$output_dir/cpuphysical-$fileext.csv") or die "Cannot open $output_dir/cpuphysical-$fileext.csv for writing $! \n";
   print OUT "Date,cpuPhysical,cpuEntitled\n";
   foreach $key (sort keys %csvdata) {
      print OUT "$csvdata{$key}{seconds_since_epoch},";	
      print OUT "$csvdata{$key}{cpuPhysical},";	
      print OUT "$csvdata{$key}{cpuEntitled}";		#no trailing comma for the last field
      print OUT "\n";
   } 							#end of foreach loop
   close OUT;						#close filehandle
   #
   # create CSV file with paging space info
   open (OUT,">$output_dir/pagingspace-$fileext.csv") or die "Cannot open $output_dir/pagingspace-$fileext.csv for writing $! \n";
   print OUT "Date,pagespaceTotal,pagespaceUsed\n";
   foreach $key (sort keys %csvdata) {
      print OUT "$csvdata{$key}{seconds_since_epoch},";	
      print OUT "$csvdata{$key}{pagespaceTotal},";	
      print OUT "$csvdata{$key}{pagespaceUsed}";	#no trailing comma for the last field
      print OUT "\n";
   } 							#end of foreach loop
   close OUT;						#close filehandle
   #
   # create CSV file with paging in/out activity
   open (OUT,">$output_dir/paginginout-$fileext.csv") or die "Cannot open $output_dir/paginginout-$fileext.csv for writing $! \n";
   print OUT "Date,pagingIn,pagingOut\n";
   foreach $key (sort keys %csvdata) {
      print OUT "$csvdata{$key}{seconds_since_epoch},";	
      print OUT "$csvdata{$key}{pagingIn},";	
      print OUT "$csvdata{$key}{pagingOut}";		#no trailing comma for the last field
      print OUT "\n";
   } 							#end of foreach loop
   close OUT;						#close filehandle
   #
   #
   #print $rrd->dump();
   #print $rrd->info();
   $rrd->close(); 					#close object
} 							#end of subroutine




sub create_daily_csv {
   #
   print "running create_daily_csv subroutine \n" if ($verbose eq "yes");
   #
   # variables for generating daily CSV files
   %csvdata    = ();					#initialize hash
   $start      = $seconds_since_epoch - 86400;		#86400 seconds = 1 day ago
   $end        = $seconds_since_epoch - 0;		#end time is now
   $resolution = 300;					#values averaged over 300 seconds
   $fileext    = "day";					#append to CSV filename
   #
   export_rrd_to_csv;					# call subroutine with variables set to daily
} 							#end of subroutine


sub create_weekly_csv {
   #
   print "running create_weekly_csv subroutine \n" if ($verbose eq "yes");
   #
   # variables for generating weekly CSV files
   %csvdata    = ();					#initialize hash
   $start      = $seconds_since_epoch - 604800;		#604800 seconds = 7 days ago
   $end        = $seconds_since_epoch - 0;		#end time is now
   $resolution = 900;					#values averaged over 900 seconds
   $fileext    = "week";				#append to CSV filename
   #
   export_rrd_to_csv;					# call subroutine with variables set to daily
} 							#end of subroutine


sub create_monthly_csv {
   #
   print "running create_monthly_csv subroutine \n" if ($verbose eq "yes");
   #
   # variables for generating monthly CSV files
   %csvdata    = ();					#initialize hash
   $start      = $seconds_since_epoch - 2678400;	#2678400 seconds = 31 days ago
   $end        = $seconds_since_epoch - 0;		#end time is now
   $resolution = 900;					#values averaged over 900 seconds
   $fileext    = "month";				#append to CSV filename
   #
   export_rrd_to_csv;					# call subroutine with variables set to daily
} 							#end of subroutine

sub create_yearly_csv {
   #
   print "running create_yearly_csv subroutine \n" if ($verbose eq "yes");
   #
   # variables for generating yearly CSV files
   %csvdata    = ();					#initialize hash
   $start      = $seconds_since_epoch - 31536000;	#31536000 seconds = 365 days ago
   $end        = $seconds_since_epoch - 0;		#end time is now
   $resolution = 900;					#values averaged over 900 seconds
   $fileext    = "year";				#append to CSV filename
   #
   export_rrd_to_csv;					# call subroutine with variables set to daily
} 							#end of subroutine



#sub create_graphs {
#   #
#   print "running create_graphs subroutine \n" if ($verbose eq "yes");
#   #
#   #
#   # define the hexadecimal codes for colors that RRDTOOL uses
#   $black  = "#000000";
#   $white  = "#ffffff";
#   $red    = "#ff0000";
#   $orange = "#ffbf00";
#   $green  = "#00ff00";
#   $blue   = "#0000ff";
#   $purple = "#ff00ff";
#   $yellow = "#ffff00";
#   #
#   $common_switches = "--title \"Physical Memory Usage\" --vertical-label \"Memory Usage\"  \\
#                       --lazy --width 800 --height 100 --imgformat PNG --base 1024          \\
#                       --watermark \"$year-$mon-$mday $hour:$min\"                          \\
#                       --slope-mode                                                         \\
#                       --lower-limit 0                                                      \\
#                       DEF:total_mem=$output_file.rrd:total_mem:AVERAGE                     \\
#                       DEF:comp_mem=$output_file.rrd:comp_mem:AVERAGE                       \\
#                       DEF:fscache=$output_file.rrd:fscache:AVERAGE                         \\
#                       DEF:free_mem=$output_file.rrd:free_mem:AVERAGE                       \\
#                       VDEF:first_date=total_mem,FIRST                                      \\
#                       VDEF:last_date=total_mem,LAST                                        \\
#                       GPRINT:first_date:\"%c\":strftime                                    \\
#                       GPRINT:last_date:\"to %c\\c\":strftime                               \\
#                       LINE1:total_mem$white:\"Total Memory\"                               \\
#                       GPRINT:total_mem:LAST:\"%.2lf %s \\n\"                               \\
#                       AREA:comp_mem$blue:\"Computational Memory\"                          \\
#                       GPRINT:comp_mem:LAST:\"%.2lf%s \\n\"                                 \\
#                       AREA:fscache$orange:\"Filesystem Cache\":STACK                       \\
#                       GPRINT:fscache:LAST:\"%.2lf %s \"                                    \\
#                       COMMENT:\"                                               \"          \\
#                       COMMENT:\"Filesystem cache normally uses all free RAM, \\n\"         \\
#                       AREA:free_mem$purple:\"Free Memory\":STACK                           \\
#                       GPRINT:free_mem:LAST:\"%.2lf %s \"                                   \\
#                       COMMENT:\"                                                        \" \\
#                       COMMENT:\"so do not worry about low free memory. \\n\"               ";
#                      
#   #
#   # create graph for the past hour
#   $cmd = "$rrdtool graph $output_file-hour.png --start -3600 $common_switches";
#   print "   running command: $cmd \n" if ($verbose eq "yes");
#   open(IN,"$cmd|"); 	                                  #open a filehandle using command output
#   close IN; 						#close filehandle
#   #
#   # create graph for the past day
#   $cmd = "$rrdtool graph $output_file-day.png --start -1d $common_switches";
#   print "   running command: $cmd \n" if ($verbose eq "yes");
#   open(IN,"$cmd|"); 	                                  #open a filehandle using command output
#   close IN; 						#close filehandle
#   #
#   # create graph for the past week
#   $cmd = "$rrdtool graph $output_file-week.png --start -1w $common_switches";
#   print "   running command: $cmd \n" if ($verbose eq "yes");
#   open(IN,"$cmd|"); 	                                  #open a filehandle using command output
#   close IN; 						#close filehandle
#   #
#   # create graph for the past month
#   $cmd = "$rrdtool graph $output_file-month.png --start -1m $common_switches";
#   print "   running command: $cmd \n" if ($verbose eq "yes");
#   open(IN,"$cmd|"); 	                                  #open a filehandle using command output
#   close IN; 						#close filehandle
#   #
#   # create graph for the past year
#   $cmd = "$rrdtool graph $output_file-year.png --start -1y $common_switches";
#   print "   running command: $cmd \n" if ($verbose eq "yes");
#   open(IN,"$cmd|"); 	                                  #open a filehandle using command output
#   close IN; 						#close filehandle
#   #
#} 							#end of subroutine





# --------------------- main body of script -------------------------------
get_options;
sanity_checks;
get_date;
get_memory_util;
get_pagingspace_util;
get_cpu_and_paging;
get_disk_latency;
create_rrd;
update_rrd;
create_daily_csv;
create_weekly_csv;
create_monthly_csv;
create_yearly_csv;
#create_graphs;
