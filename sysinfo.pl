#!/usr/bin/perl
#
#
# CHANGE LOG
# ----------
# 2016/08/15 njeffrey	Script created
# 2017/02/15 njeffrey	Convert from bourne shell to perl
#
#
# NOTES
# -----
# Script to generate sysinfo.html file for inventory reference 
#
# This script needs to run as the root user because the following commands require root privileges:
#   lsitab
#   lsiscsi
#   vmo
#   lsuser ALL
#   lsgroup ALL
#
# It is assumed that this script runs daily from the root crontab.  For example:
# 56 22 * * * /home/arrdvark/sysinfo.pl >/home/arrdvark/sysinfo.html 2>&1 #generate system info report


use strict;							#enforce good coding practices




# declare variables
my ($date,$verbose,$cmd,$key,$section_title);
my ($hostname,$uptime,$prtconf,$errpt,$lslpp,$lsfs,$df,$lsvg,$lsdev,$lscons,$lspath,$lsuser,$lsgroup,$lscfg,$lsnfsexp,$lsnfsmnt,$lsmcode);
my ($lparstat,$lsitab,$lsiscsi,$ifconfig,$mpstat,$netstat,$no,$proctree,$lspv,$lsps,$lsattr,$uname,$fcstat,$entstat,$cat);
my (%ent,%fcs,%hdisk);
$date       = `date`;  chomp $date;                             #get the current date
$hostname   = "/usr/bin/hostname";
$uptime     = "/usr/bin/uptime";
$prtconf    = "/usr/sbin/prtconf";
$errpt      = "/usr/bin/errpt";
$lslpp      = "/usr/bin/lslpp";
$lsfs       = "/usr/sbin/lsfs";
$df         = "/usr/bin/df";
$lsvg       = "/usr/sbin/lsvg";
$lsdev      = "/usr/sbin/lsdev";
$lscons     = "/usr/sbin/lscons";
$lspath     = "/usr/sbin/lspath";
$lsuser     = "/usr/sbin/lsuser";
$lsgroup    = "/usr/sbin/lsgroup";
$lscfg      = "/usr/sbin/lscfg";
$lsnfsexp   = "/usr/sbin/lsnfsexp";
$lsnfsmnt   = "/usr/sbin/lsnfsmnt";
$lsmcode    = "/usr/sbin/lsmcode";
$lparstat   = "/usr/bin/lparstat";
$lsitab     = "/usr/sbin/lsitab";
$lsiscsi    = "/usr/sbin/lsiscsi";
$ifconfig   = "/usr/sbin/ifconfig";
$mpstat     = "/usr/bin/mpstat";
$netstat    = "/usr/bin/netstat";
$no         = "/usr/sbin/no";
$proctree   = "/usr/bin/proctree";
$lspv       = "/usr/sbin/lspv";
$lsps       = "/usr/sbin/lsps";
$lsattr     = "/usr/sbin/lsattr";
$uname      = "/usr/bin/uname";
$fcstat     = "/usr/bin/fcstat";
$entstat    = "/usr/bin/entstat";
$cat        = "/usr/bin/cat";




sub sanity_checks {
   #
   print "running sanity_checks subroutine \n" if ($verbose eq "yes");
   #
   $_ = $hostname;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $uptime;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $prtconf;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $errpt;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lslpp;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsfs;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $df;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsvg;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsdev;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lscons;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lspath;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsuser;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsgroup;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lscfg;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsnfsexp;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsnfsmnt;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsmcode;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lparstat;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsitab;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsiscsi;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $ifconfig;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $mpstat;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $no;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $proctree;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lspv;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsps;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $lsattr;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $uname;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $fcstat;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $entstat;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   $_ = $cat;
   if ( ! -e $_ ) { print "Error - $_ does not exist                       \n"; exit; }
   if ( ! -x $_ ) { print "Error - $_ is not executable by the current user\n"; exit; }
   #
   # confirm this machine is running AIX
   $cmd = "$uname";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   open (IN,"$cmd |");
   while (<IN>) {                                       #read a line from the filehandle
      unless ( /AIX/ ) {                                #confirm system is running AIX
         print "   ERROR: This script only runs on AIX \n";
         exit;
      }                                                 #end of unless block
   }                                                    #end of while loop
   close IN;                                            #close filehandle
}





sub print_html_header {
   #
   print "running print_html_header subroutine \n" if ($verbose eq "yes");
   #
   # print HTML headers
   print "<html><head><META http-equiv=refresh content=3600><title>AIX Inventory Information</title></head><body> \n";
   print "<h1>AIX Inventory Report</h1> \n";
   print "<p>This report was automatically generated by the $0 script at $date \n";
   print "<p>&nbsp; \n";
}      




sub print_data {
   #
   print "running print_data subroutine \n" if ($verbose eq "yes");
   #
   # this subroutine is repeatedly called by the get_inventory_data subroutine
   #
   print "<hr><h3> $section_title </h3> \n";
   print "<pre> \n";
   open (IN,"$cmd |");
   while (<IN>) {                                       #read a line from the filehandle
      print $_;
   }                                                    #end of while loop
   close IN;                                            #close filehandle
   print "</pre> \n";
}





sub get_inventory_data {
   #
   print "running get_inventory_data subroutine \n" if ($verbose eq "yes");
   #
   $section_title = "hostname"        ; $cmd = "hostname"         ; print_data;
   $section_title = "uptime"          ; $cmd = "uptime"           ; print_data;
   $section_title = "prtconf"         ; $cmd = "prtconf"          ; print_data;
   $section_title = "errpt"           ; $cmd = "errpt"            ; print_data;
   $section_title = "errpt -a"        ; $cmd = "errpt -a"         ; print_data;
   $section_title = "lslpp -l"        ; $cmd = "lslpp -l"         ; print_data;
   $section_title = "lsfs"            ; $cmd = "lsfs"             ; print_data;
   $section_title = "lsfs -l"         ; $cmd = "lsfs -l"          ; print_data;
   $section_title = "df -m"           ; $cmd = "df -m"            ; print_data;
   $section_title = "df -g"           ; $cmd = "df -g"            ; print_data;
   $section_title = "lsvg"            ; $cmd = "lsvg"             ; print_data;
   $section_title = "lsvg -o"         ; $cmd = "lsvg -o"          ; print_data;
   $section_title = "lsdev"           ; $cmd = "lsdev"            ; print_data;
   $section_title = "lscons"          ; $cmd = "lscons"           ; print_data;
   $section_title = "lspath"          ; $cmd = "lspath"           ; print_data;
   $section_title = "lsuser  ALL"     ; $cmd = "lsuser  ALL"      ; print_data;
   $section_title = "lsgroup ALL"     ; $cmd = "lsgroup ALL"      ; print_data;
   $section_title = "lscfg"           ; $cmd = "lscfg"            ; print_data;
   $section_title = "lscfg -vp"       ; $cmd = "lscfg -vp"        ; print_data;
   $section_title = "resolv.conf"     ; $cmd = "test -f /etc/resolv.conf && cat /etc/resolv.conf" ; print_data;
   $section_title = "lsnfsexp"        ; $cmd = "test -f /etc/exports && lsnfsexp"      ; print_data;
   $section_title = "lsnfsmnt"        ; $cmd = "lsnfsmnt"         ; print_data;
   $section_title = "lsmcode"         ; $cmd = "lsmcode"          ; print_data;
   $section_title = "lparstat"        ; $cmd = "lparstat"         ; print_data;
   $section_title = "lparstat -i"     ; $cmd = "lparstat -i"      ; print_data;
   $section_title = "lsitab -a"       ; $cmd = "lsitab -a"        ; print_data;
   $section_title = "lsiscsi"         ; $cmd = "lsiscsi"          ; print_data;
   $section_title = "ifconfig -a"     ; $cmd = "ifconfig -a"      ; print_data;
   $section_title = "mpstat"          ; $cmd = "mpstat"           ; print_data;
   $section_title = "netstat -rn"     ; $cmd = "netstat -rn"      ; print_data;
   $section_title = "netstat -i"      ; $cmd = "netstat -i"       ; print_data;
   $section_title = "proctree"        ; $cmd = "proctree"         ; print_data;
   $section_title = "lspv"            ; $cmd = "lspv"             ; print_data;
   $section_title = "lsps -a"         ; $cmd = "lsps -a"          ; print_data;
   $section_title = "lsps -s"         ; $cmd = "lsps -s"          ; print_data;
   $section_title = "lsattr -El sys0" ; $cmd = "lsattr -El sys0"  ; print_data;
   $section_title = "no -a"           ; $cmd = "no -a"            ; print_data;
   $section_title = "oslevel -s"      ; $cmd = "oslevel -s"       ; print_data;
   $section_title = "vmo -a"          ; $cmd = "vmo -a"           ; print_data;
   $section_title = "who"             ; $cmd = "who"              ; print_data;
   $section_title = "who -a"          ; $cmd = "who -a"           ; print_data;
}




sub get_complicated_data {
   #
   print "running get_complicated_data subroutine \n" if ($verbose eq "yes");
   #
   # This subroutine gathers data that requires more complex processing
   #
   #
   #
   $section_title = "Ethernet Statistics";
   $cmd = "$lsdev";					#get a listing of all devices
   open (IN,"$cmd |");
   while (<IN>) {                                       #read a line from the filehandle
      if ( /(^ent[0-9]+)/ ) {				#find the ent# ethernet devices
         $ent{$1}{name} = $1;				#add name of ent# ethernet device as hash key
      } 						#end of if block
   }                                                    #end of while loop
   close IN;                                            #close filehandle
   #
   print "<hr><h3> $section_title </h3> \n";		
   foreach $key ( sort keys %ent ) {     		#loop through the hash of ethernet adapters
      print "<h4> entstat -d $key </h4> \n";		#print a header for each ent# device
      print "<pre> \n";
      $cmd = "$entstat -d $key";			#run entstat -d against each ethernet adapter
      open (IN,"$cmd |");
      while (<IN>) {                                    #read a line from the filehandle
         print $_;					#print the output of entstat -d ent#
      }                                                 #end of while loop
      close IN;                                         #close filehandle
      print "</pre> \n";
   }                                                    #end of foreach block
   #
   #
   #
   $section_title = "Ethernet Attributes";
   $cmd = "$lsdev";					#get a listing of all devices
   open (IN,"$cmd |");
   while (<IN>) {                                       #read a line from the filehandle
      if ( /(^ent[0-9]+)/ ) {				#find the ent# ethernet devices
         $ent{$1}{name} = $1;				#add name of ent# ethernet device as hash key
      } 						#end of if block
   }                                                    #end of while loop
   close IN;                                            #close filehandle
   #
   print "<hr><h3> $section_title </h3> \n";		
   foreach $key ( sort keys %ent ) {     		#loop through the hash of ethernet adapters
      print "<h4> lsattr -El $key </h4> \n";		#print a header for each ent# device
      print "<pre> \n";
      $cmd = "$lsattr -El $key";			#run lsattr -El against each ethernet adapter
      open (IN,"$cmd |");
      while (<IN>) {                                    #read a line from the filehandle
         print $_;					#print the output of lsattr -El ent#
      }                                                 #end of while loop
      close IN;                                         #close filehandle
      print "</pre> \n";
   }                                                    #end of foreach block
   #
   #
   #
   $section_title = "Fibre Channel Statistics";
   $cmd = "$lsdev";					#get a listing of all devices
   open (IN,"$cmd |");
   while (<IN>) {                                       #read a line from the filehandle
      if ( /(^fcs[0-9]+)/ ) {				#find the fcs# fibre channel devices
         $fcs{$1}{name} = $1;				#add name of fcs# fibre channel device as hash key
      } 						#end of if block
   }                                                    #end of while loop
   close IN;                                            #close filehandle
   #
   print "<hr><h3> $section_title </h3> \n";		
   foreach $key ( sort keys %fcs ) {     		#loop through the hash of fibre channel adapters
      print "<h4> fcstat $key </h4> \n";		#print a header for each fcs# device
      print "<pre> \n";
      $cmd = "$fcstat $key";				#run entstat -d against each ethernet adapter
      open (IN,"$cmd |");
      while (<IN>) {                                    #read a line from the filehandle
         print $_;					#print the output of fcstat fcs#
      }                                                 #end of while loop
      close IN;                                         #close filehandle
      print "</pre> \n";
   }                                                    #end of foreach block
   #
   #
   #
   $section_title = "Fibre Channel Attributes";
   $cmd = "$lsdev";					#get a listing of all devices
   open (IN,"$cmd |");
   while (<IN>) {                                       #read a line from the filehandle
      if ( /(^fcs[0-9]+)/ ) {				#find the fcs# fibre channel devices
         $fcs{$1}{name} = $1;				#add name of fcs# fibre channel device as hash key
      } 						#end of if block
   }                                                    #end of while loop
   close IN;                                            #close filehandle
   #
   print "<hr><h3> $section_title </h3> \n";		
   foreach $key ( sort keys %fcs ) {     		#loop through the hash of fibre channel adapters
      print "<h4> lsattr -El $key </h4> \n";		#print a header for each fcs# device
      print "<pre> \n";
      $cmd = "$lsattr -El $key";			#run lsattr -El against each fibre channel adapter
      open (IN,"$cmd |");
      while (<IN>) {                                    #read a line from the filehandle
         print $_;					#print the output of lsattr -El fcs#
      }                                                 #end of while loop
      close IN;                                         #close filehandle
      print "</pre> \n";
   }                                                    #end of foreach block
   #
   #
   #
   $section_title = "Hard Disk Attributes";
   $cmd = "$lsdev";					#get a listing of all devices
   open (IN,"$cmd |");
   while (<IN>) {                                       #read a line from the filehandle
      if ( /(^hdisk[0-9]+)/ ) {				#find the hdisk# devices
         $hdisk{$1}{name} = $1;				#add name of hdisk# device as hash key
      } 						#end of if block
   }                                                    #end of while loop
   close IN;                                            #close filehandle
   #
   print "<hr><h3> $section_title </h3> \n";		
   foreach $key ( sort keys %hdisk ) {     		#loop through the hash of fibre channel adapters
      print "<h4> lsattr -El $key </h4> \n";	#print a header for each hdisk# device
      print "<pre> \n";
      $cmd = "$lsattr -El $key";				#run lsattr -El hdisk# for each hdisk
      open (IN,"$cmd |");
      while (<IN>) {                                    #read a line from the filehandle
         print $_;					#print the output of lsattr -El hdisk#
      }                                                 #end of while loop
      close IN;                                         #close filehandle
      print "</pre> \n";
   }                                                    #end of foreach block
}





sub print_html_footer {
   #
   print "running print_html_footer subroutine \n" if ($verbose eq "yes");
   #
   print "</table></body></html>"     
}





# ---------- main body of script --------------------
sanity_checks;
print_html_header;
get_inventory_data;
get_complicated_data;
print_html_footer;
