#!/usr/bin/perl -w

# script to record AIX memory usage in RRD file and create graphs


# CHANGE LOG
# ----------
#  2016/03/26	njeffrey	Script created
#  2016/03/31	njeffrey	switch from rrdtool binary to RRD::Editor perl module





# OUTSTANDING TASKS
# -----------------
# only recreate daily graphs every 4 hours, weekly graphs every day, etc
# getting unreasonably high numbers for CPU util - suspect this script is spiking CPU.  Try getting data from nmon instead.  Only need to update get_perf subroutine.
# add error check to confirm rrd file gets created and effective user has write access
# set default working directory to /usr/local/arrdvark 



# NOTES
# ------
# It is assumed that this script is run every 5 minutes from cron
# This script will keep 1 year of CSV data, and automatically truncate data older than 1 year.



use strict;						#enforce good coding practices
use Getopt::Long;                                       #allow --long-switches to be used as parameters
use RRD::Editor ();					#use external perl module (see readme for install instructions)


#declare variables
my ($cmd,$vmstat,$lsps,$uname,$rrdtool,$rrd);
my ($mem_total,$mem_comp,$mem_noncomp,$mem_free);
my ($pagespace_total,$pagespace_used,$paging_in,$paging_out);
my ($cpu_sys_pct,$cpu_user_pct,$cpu_idle_pct,$cpu_wait_pct,$cpu_physical,$cpu_entitled);
my ($output_file,$verbose,$version);
my ($opt_h,$opt_v,$opt_V);
my ($common_switches);
my ($black,$white,$red,$orange,$green,$blue,$purple,$yellow);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst,$seconds_since_epoch);
$vmstat      = "/usr/bin/vmstat";
$lsps        = "/usr/sbin/lsps";
$uname       = "/usr/bin/uname";
$output_file = "/tmp/arrdvark.mem";
$rrdtool     = "/usr/bin/rrdtool";
$version     = "20160326";				#last update to script in yyyymmdd format





sub get_options {
   #
   # this gets the command line parameters provided by the users
   #
   #
   Getopt::Long::Configure('bundling');
   GetOptions(
      "h"   => \$opt_h, "help"     => \$opt_h,
      "v"   => \$opt_v, "verbose"  => \$opt_v,
      "V"   => \$opt_V, "version"  => \$opt_v,
   );
   #
   #
   #
   # If the user supplied -h or --help, generate the help messages
   #
   if( defined( $opt_h ) ) {
      print "Script to save AIX physical memory usage statistics in a CSV file  \n";
      print "Examples: $0           \n";
      print "          $0 --verbose \n";
      print "          $0 --version \n";
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
   }
}                                                                          #end of subroutine





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
   $_ = $uname; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $rrdtool; 
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   #
   #confirm system is running AIX
   $cmd = "$uname";
   open(IN,"$cmd|");                                    #open a filehandle using command output
   while (<IN>) {                                       #read a line from STDIN
      unless ( /AIX/ ) {                                #confirm system is running AIX
         print "ERROR: this script only runs on AIX \n";
         exit;
      }                                                 #end of unless block
   }                                                    #end of while loop
   close IN;                                            #close filehandle
   #
   #
#   # confirm output file is writeable (if it exists yet)
#   if ( -e $output_file  ) {
#      if ( ! -w $output_file  ) {
#         print "ERROR: $output_file CSV data file is not writeable by the current user \n";
#         exit;
#      }
#   }
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
   #
   $seconds_since_epoch = time();
}                                                       #end of subroutine





sub get_perfdata {
   #
   print "running get_perfdata subroutine \n" if ($verbose eq "yes");
   #
   #
   # Initialize variables so we can perform addition/division for averaging
   $mem_total       = 0;
   $mem_free        = 0;
   $mem_comp        = 0;
   $mem_noncomp     = 0;
   $pagespace_total = 0;
   $pagespace_used  = 0;
   $paging_in       = 0;
   $paging_out      = 0;
   $cpu_user_pct    = 0;
   $cpu_sys_pct     = 0;
   $cpu_idle_pct    = 0;
   $cpu_wait_pct    = 0;
   $cpu_physical    = 0;
   $cpu_entitled    = 0;
   #
   #
   # Get physical memory utilization
   #
   $cmd = "$vmstat -v"; 					#command to be run
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open(IN,"$cmd|");                                    	#open a filehandle using command output
   while (<IN>) {                                       	#read a line from STDIN
      if ( /([0-9\.]+) +memory pages/ ) {               	#find the vmstat output that shows number of memory pages
         $mem_total = $1;                               	#assign to variable
         $mem_total= $mem_total * 4096;                		#multiply memory pages by 4096 to get bytes of memory
         $mem_total = sprintf( "%.2f", $mem_total);     	#truncate to 2 decimal place
      }                                                 	#end of if block
      if ( /([0-9\.]+) +free pages/ ) {                 	#find the vmstat output that shows number of free memory pages
         $mem_free  = $1;                               	#assign to variable
         $mem_free  = $mem_free * 4096;                 	#multiply memory pages by 4096 to get bytes of memory
         $mem_free  = sprintf( "%.2f", $mem_free);     	 	#truncate to 1 decimal place
      }                                                 	#end of if block
      if ( /([0-9\.]+) +numclient percentage/ ) {       	#find the percentage of memory used by client paging (filesystem cache)
         $mem_noncomp = $1;                                 	#assign to variable
         $mem_noncomp = $mem_noncomp * $mem_total / 100;        #convert percentage used to Gigabytes used by filesystem cache
         $mem_noncomp = sprintf( "%.2f", $mem_noncomp);         #truncate to 1 decimal place
      }                                                 	#end of if block
      if ( /([0-9\.]+) +percentage of memory used for computational pages/ ) {     #find the percentage of memory used by computational pages
         $mem_comp = $1;                                	#assign to variable
         $mem_comp = $mem_comp * $mem_total / 100;      	#convert percentage used to Gigabytes used by filesystem cache
         $mem_comp = sprintf( "%.2f", $mem_comp);       	#truncate to 1 decimal place
      }                                                 	#end of if block
   }                                                    	#end of while loop
   close IN;                                            	#close filehandle
   print "   Total memory:$mem_total, Free memory:$mem_free, Computational Memory:$mem_comp, Filesystem Cache:$mem_noncomp \n" if ($verbose eq "yes");
   #
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
         $pagespace_total = $1;            				#assign to variable
         $pagespace_total = $pagespace_total * 1024 * 1024;  		#convert from megabytes to bytes
         $pagespace_used = $2;            				#assign to variable
         $pagespace_used  = $pagespace_total * $pagespace_used / 100; 	#convert from percentage to bytes
      }                                                 		#end of if block
   }                                                    		#end of while loop
   close IN;                                            		#close filehandle
   print "   Total paging space:$pagespace_total bytes, Used:$pagespace_used bytes\n" if ($verbose eq "yes");
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
   $cmd = "$vmstat 1 10"; 				#command to be run
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open(IN,"$cmd|");                                    		#open a filehandle using command output
   while (<IN>) {                                       		#read a line from STDIN
      if ( /^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +([0-9]+) +([0-9]+) / ) {  	#find the command output that shows paging activity
         $paging_in  = $paging_in +$1; 					#running total of paging activity
         $paging_out = $paging_out + $2;         			#running total of  paging activity
      }                                                 		#end of if block
      #
      #find the command output that shows CPU percentage used (columns us sy id wa)
      if ( /^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) / ) {  
         $cpu_user_pct = $1;           					#assign to variable
         $cpu_sys_pct  = $2;           					#assign to variable
         $cpu_idle_pct = $3;           					#assign to variable
         $cpu_wait_pct = $4;           					#assign to variable
      }                                                 		#end of if block
   }                                                    		#end of while loop
   close IN;                                            		#close filehandle
   #
   # At this point, we have 10 data points for paging activity and CPU usage.
   # Figure out the average of those data points.
   $paging_in    = $paging_in * 4096;  					#multiply by number of 4096 byte memory pages to get bytes 
   $paging_in    = $paging_in / 10; 					#get average of 10 data points from vmstat
   $paging_in    = sprintf( "%.0f", $paging_in);     			#truncate to 0 decimal place
   $paging_out   = $paging_out * 4096;  				#multiply by number of 4096 byte memory pages to get bytes 
   $paging_out   = $paging_out / 10; 					#get average of 10 data points from vmstat
   $paging_out   = sprintf( "%.0f", $paging_out);     			#truncate to 0 decimal place
   $cpu_user_pct = $cpu_user_pct / 10; 					#get average of 10 data points from vmstat
   $cpu_user_pct = sprintf( "%.1f", $cpu_user_pct);     		#truncate to 1 decimal place
   $cpu_sys_pct  = $cpu_sys_pct / 10; 					#get average of 10 data points from vmstat
   $cpu_sys_pct  = sprintf( "%.1f", $cpu_sys_pct);	     		#truncate to 1 decimal place
   $cpu_idle_pct = $cpu_idle_pct / 10; 					#get average of 10 data points from vmstat
   $cpu_idle_pct = sprintf( "%.1f", $cpu_idle_pct);     		#truncate to 1 decimal place
   $cpu_wait_pct = $cpu_wait_pct / 10; 					#get average of 10 data points from vmstat
   $cpu_wait_pct = sprintf( "%.1f", $cpu_wait_pct);	     		#truncate to 1 decimal place
   #
   print "   Paging activity  in:$paging_in bytes   out:$paging_out bytes \n" if ($verbose eq "yes");
   print "   CPU\% user:$cpu_user_pct system:$cpu_sys_pct idle:$cpu_idle_pct wait:$cpu_wait_pct \n" if ($verbose eq "yes");
} 									#end of subroutine



sub create_rrd {
   #
   print "running create_rrd subroutine \n" if ($verbose eq "yes");
   #
   # Create an RRD file that will contain 365 days of data a 5 minute data points ( 60 seconds * 60 minutes / 300 seconds * 24 hours * 365 days = 101520)
   #
   if ( -e "$output_file.rrd" )	 {		#break out of subroutine if RRD file already exists
      print "   $output_file.rrd already exists \n" if ($verbose eq "yes");
      return;
   }
   #
#   $cmd = "$rrdtool create $output_file.rrd --step 300 DS:total_mem:GAUGE:600:U:U DS:comp_mem:GAUGE:600:U:U DS:fscache:GAUGE:600:U:U DS:free_mem:GAUGE:600:U:U RRA:AVERAGE:0.5:5m:105120";
#   print "   running command: $cmd \n" if ($verbose eq "yes");
#   open(IN,"$cmd|");                                    #open a filehandle using command output
#   while (<IN>) {                                       #read a line from STDIN
#   } 							#end of while loop
#   close IN; 						#close filehandle
#   #
#   # confirm .rrd file was created
#   unless ( -e "$output_file.rrd" ) {
#      print "ERROR: $output_file.rrd was not created.  Please check permissions. \n";
#      exit;  						#exit script
#   } 							#end of unless block
   #
   #
   $rrd = RRD::Editor->new();				#create a new object
   $rrd->create("DS:mem_total:GAUGE:600:U:U 
                 DS:mem_comp:GAUGE:600:U:U 
                 DS:mem_noncomp:GAUGE:600:U:U 
                 DS:mem_free:GAUGE:600:U:U 
                 DS:pagespace_total:GAUGE:600:U:U 
                 DS:pagespace_used:GAUGE:600:U:U 
                 DS:paging_in:GAUGE:600:U:U 
                 DS:paging_out:GAUGE:600:U:U 
                 DS:cpu_user_pct:GAUGE:600:U:U 
                 DS:cpu_sys_pct:GAUGE:600:U:U 
                 DS:cpu_idle_pct:GAUGE:600:U:U 
                 DS:cpu_wait_pct:GAUGE:600:U:U 
                 DS:cpu_physical:GAUGE:600:U:U 
                 DS:cpu_entitled:GAUGE:600:U:U 
                 RRA:AVERAGE:0.5:300:105120
                "); 					#create RRD
   $rrd->save("$output_file.rrd");  			#save RRD to file
   $rrd->close(); 					#close object
} 							#end of subroutine



sub update_rrd {
   #
   print "running update_rrd subroutine \n" if ($verbose eq "yes");
   #
   #
   #$cmd = "$rrdtool update $output_file.rrd N:$total_mem:$comp_mem:$fscache:$free_mem";
   #print "   running command: $cmd \n" if ($verbose eq "yes");
   #open(IN,"$cmd|");                                    #open a filehandle using command output
   #while (<IN>) {                                       #read a line from STDIN
   #} 							#end of while loop
   #close IN; 						#close filehandle
   #
   print "   Adding these values to RRD file  $seconds_since_epoch:$mem_total:$mem_comp:$mem_noncomp:$mem_free:$pagespace_total:$pagespace_used:$paging_in:$paging_out:$cpu_user_pct:$cpu_sys_pct:$cpu_idle_pct:$cpu_wait_pct:$cpu_physical:$cpu_entitled \n" if ($verbose eq "yes");
   #
   $rrd = RRD::Editor->new();				#create a new object
   $rrd->open("$output_file.rrd");			#open the RRD file
   $rrd->update("N:$mem_total:$mem_comp:$mem_noncomp:$mem_free:$pagespace_total:$pagespace_used:$paging_in:$paging_out:$cpu_user_pct:$cpu_sys_pct:$cpu_idle_pct:$cpu_wait_pct:$cpu_physical:$cpu_entitled"); #add data to the RRD file
   $rrd->close(); 					#close object
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
get_perfdata;
create_rrd;
update_rrd;
#create_graphs;
