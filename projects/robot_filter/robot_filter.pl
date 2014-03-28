#!/usr/bin/perl -w
#
# robot_filter.pl
#
# The purpose of this program is to screen unwanted telemarketing robots from
# repeated calls by using the modem to identify the caller and pickup and answer
# the phone (negotiate connection to dialing modem).  With some luck this may
# actually encourage the telemarketer to remove your number from their calling
# list but at the very least they'll be prevented from connecting with an actual
# human.
#
# Requirements:
# 1 modem with caller id (something like the USRobotics USR5637 USB modem)
# 1 computer running perl (I'm using FreeBSD 10, but perl runs on many platforms)
# 1 copy of Device::Modem from CPAN (http://search.cpan.org/perldoc?Device%3A%3AModem)
#
# The program runs as a daemon, storing it's process id in the robot_filter.pid
# file.  To shutdown the program simply kill the process id and the program will
# terminate.  On startup the robot filter loads it's configuration from a comma
# separated value file caller_config.csv, it has a format of:
#
# entry_type|phone_number|caller_id_name
#
# For example:
#
# w|2065551212|
#
# means whitelist number 2065551212, which allows calls from that number to pass
# through without screening.  The caller_id_name is optional.  By default the
# filter will allow calls to pass through and store the caller id information in
# a file unknown_callers.csv for later examination.  To blacklist a caller and
# screen them out, in the caller_config.csv file create an entry like one of:
#
# B||
# B|4805551212|
# B|4045551212|MRROBOTO
# 
# The first entry B|| will pick up and screen all calls where the name and number
# are blocked from caller id.  The second entry B|4805551212| will pick up and
# screen all calls identified as the number 4805551212.  The third entry
# B|4045551212|MRROBOTO picks up and screens all calls from the number 4045551212
# or any calls originating with the caller id name of MRROBOTO (which may be useful
# for screening telemarketing companies using many different numbers).  A record
# of all calls the filter answered is stored in the answered_calls.csv file.  The
# format of both answered_calls.csv and unknown_callers.csv is:
#
# "date_time_stamp","caller_number","caller_name"
#
# for example:
#
# "2014-03-21T20:15:31","","O"
#
# represents a call at 8:15 pm on March 21st, 2014 from a blocked number with a
# caller id name of 'O' (meaning Out of Area).
#
# This script is free for noncommercial use in part or in full and provided with
# absolutely no warranty of any kind whatsoever.
#


use strict;
use warnings;

use Fcntl qw( :DEFAULT :flock );
use POSIX 'setsid';

use Device::Modem;

### bootstrap robot_filter.log file in /var/log/ with correct ownership/permissions
# sudo touch /var/log/robot_filter.log
# sudo chmod 640 /var/log/robot_filter.log
# sudo chown root:wheel /var/log/robot_filter.log

### bootstrap robot_filter.pid file in /var/run/ with correct ownership/permissions
# sudo touch /var/run/robot_filter.pid
# sudo chmod 640 /var/run/robot_filter.pid
# sudo chown root:daemon /var/run/robot_filter.pid


### Subroutine Declarations ###
#
sub start_pid;
sub shutdown_pid;
sub log_entry;
sub handle_signal;

sub answer_call;
sub check_areacode;
sub load_configuration;

### Initialization Parameters ###
#

my $daemonName    = 'robot_filter';

# my $logFilePath   = '/var/log/';
my $logFilePath   = '/root/filter/';
my $logFile       = $logFilePath . $daemonName . '.log';

# my $pidFilePath   = '/var/run/';
my $pidFilePath   = '/root/filter/';
my $pidFile       = $pidFilePath . $daemonName . '.pid';

# Modem Serial Connection
my $port = '/dev/cuaU0';
my $baud = 115200;

# Input/Output File Names
my $config_filename = "/root/filter/caller_config.csv";
my $answered_filename = "answered_calls.csv";
my $unknown_filename = "unknown_callers.csv";

### Shared (Global) Variables ###
#

my $shutdown  = 0;
my $loggingOn = 1;

my %whitelist = ();
my %blacklist = ();

### Subroutine Definitions ###
#

# stuff process id in daemon.pid file on startup
sub start_process_id
{
   my ( $filePath ) = @_;

   my $isOpen = 0;
   my $elapsed = 0;

   my $fileSize = -s $filePath;

   my $processId;

   if ( defined( $fileSize ) && ( $fileSize >= 0 ) )
   {
      while ( $elapsed < 40 )  # wait up to 10 seconds for timeout
      {
         if ( ( 0 == $isOpen ) && sysopen( SHARED, $filePath, O_RDWR ) )
         {
            $isOpen = 1;
         }

         if ( ( 1 == $isOpen ) && flock( SHARED, LOCK_EX | LOCK_NB ) )
         {
            if ( 0 != $fileSize )
            {
               sysread( SHARED, $processId, $fileSize );

               chomp( $processId );

               if ( `ps -p $processId` =~ m/$processId/ )
               {
                  close( SHARED );

                  die $daemonName . 'process already running...';
               }
            }

            $processId = $$;

            sysseek( SHARED, 0, 0 );

            syswrite( SHARED, $processId );

            close( SHARED );

            $isOpen = 0;

            last;
         }
         else
         {
            $elapsed += 1;

            select( undef, undef, undef, 0.25 );
         }
      }
   }
   else
   {
      while ( $elapsed < 40 )  # wait up to 10 seconds for timeout
      {
         if ( ( 0 == $isOpen ) && sysopen( SHARED, $filePath, O_WRONLY | O_CREAT ) )
         {
            $isOpen = 1;
         }

         if ( ( 1 == $isOpen ) && flock( SHARED, LOCK_EX | LOCK_NB ) )
         {
            $processId = $$;

            sysseek( SHARED, 0, 0 );

            syswrite( SHARED, $processId );

            close( SHARED );

            $isOpen = 0;

            last;
         }
         else
         {
            $elapsed += 1;

            select( undef, undef, undef, 0.25 );
         }
      }
   }

   return $processId;
}


# truncate daemon pid file when process closing
sub shutdown_process_id
{
   my ( $filePath ) = @_;

   my $isOpen = 0;
   my $elapsed = 0;

   my $fileSize = -s $filePath;

   my $processId;

   if ( defined( $fileSize ) && ( $fileSize >= 0 ) )
   {
      while ( $elapsed < 40 )  # wait up to 10 seconds for timeout
      {
         if ( ( 0 == $isOpen ) && sysopen( SHARED, $filePath, O_RDWR ) )
         {
            $isOpen = 1;
         }

         if ( ( 1 == $isOpen ) && flock( SHARED, LOCK_EX | LOCK_NB ) )
         {
            if ( 0 != $fileSize )
            {
               sysread( SHARED, $processId, $fileSize );

               chomp( $processId );

               if ( $processId eq $$ )
               {
                  truncate( SHARED, 0 );
               }
            }

            close( SHARED );

            $isOpen = 0;

            last;
         }
         else
         {
            $elapsed += 1;

            select( undef, undef, undef, 0.25 );
         }
      }
   }
}


# append a line to the log file
sub log_entry
{
   my ( $logText ) = @_;

   my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( time() );

   my $dateTime = sprintf( '%4d-%02d-%02d %02d:%02d:%02d', ( $year + 1900 ), ( $mon + 1 ), $mday, $hour, $min, $sec );

   if ( $loggingOn )
   {
      print LOG "$dateTime $logText\n";
   }
}


# set the main event loop boolean to true to exit when a signal is caught
sub handle_signal()
{
   $shutdown = 1;
}


sub answer_call
{
   my $modem = shift;

   # Initiate Dial/Answer
   $modem->atsend( 'ATA' . Device::Modem::CR );

   print $modem->parse_answer() . "\n\n";

   sleep( 30 );

   # Hang Up
   $modem->hangup();

   print $modem->parse_answer() . "\n\n";

   sleep( 3 );

   # Enable Caller ID info
   $modem->atsend( 'AT#CID=1' . Device::Modem::CR );

   print $modem->parse_answer() . "\n\n";
}


sub check_areacode
{
   my ( $modem, $number, $caller ) = @_;

   my $areacode = "";

   if ( length( $number ) > 3 )
   {
      $areacode = substr( $number, 0, 3 );
   }

   if ( exists( $whitelist{ $areacode } ) && defined( $whitelist{ $areacode } ) )
   {
      # don't worry be happy...
   }
   elsif ( exists( $blacklist{ $areacode } ) && defined( $blacklist{ $areacode } ) )
   {
      # answer immediately ATA or ATDT?

      my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( time() );

      my $iso8601date = sprintf( "%04d-%02d-%02dT%02d:%02d:%02d", ( $year + 1900 ), ( $mon + 1 ), $mday, $hour, $min, $sec );

      print ANSWERED '"' . $iso8601date . '","' . $number . '","' . $caller . '"' . "\n";

      answer_call( $modem );
   }
}


sub load_configuration
{
   my $filename = shift;

   open( INPUT, '<' . $filename ) or die "cannot open $filename for reading: $!";

   while ( <INPUT> )
   {
      chomp;

      my ( $type, $number, $name ) = split( '[|]' );

      if ( $type eq 'W' )
      {
         # whitelist Names/Numbers

         if ( length( $number ) > 0 )
         {
            $whitelist{ $number } = 'W';
         }

         if ( length( $name ) > 0 )
         {
            $whitelist{ $name } = 'W';
         }
      }
      elsif ( $type eq 'w' )
      {
         # whitelist Area Codes

         if ( length( $number ) > 0 )
         {
            $whitelist{ $number } = 'w';
         }
      }
      elsif ( $type eq 'B' )
      {
         # blacklist Names/Numbers

         if ( length( $number ) > 0 )
         {
            $blacklist{ $number } = 'B';
         }
         else
         {
            $blacklist{ "" } = 'B';
         }

         if ( length( $name ) > 0 )
         {
            $blacklist{ $name } = 'B';
         }
      }
      elsif ( $type eq 'b' )
      {
         # blacklist Area Codes

         if ( length( $number ) > 0 )
         {
            $blacklist{ $number } = 'b';
         }
      }
   }

   close ( INPUT ); 
}




### Start Program ###
#

# disassociate standard handles for parent process

chdir( '/' );
umask( 0 );

open( STDIN,  '/dev/null' ) or die "Can't read /dev/null: $!";
open( STDOUT, '>>/dev/null' ) or die "Can't write to /dev/null: $!";
open( STDERR, '>>/dev/null' ) or die "Can't write to /dev/null: $!";

$0 = uc( $daemonName );

defined( my $pid = fork() ) or die "Can't fork: $!";

if( $pid )
{
   exit();
}

# attempt daemonize
 
# create a new session to remove process from the controlling ( starting ) terminal
# and stop being part of whatever process group this process was a part of.

POSIX::setsid() or die( "POSIX::setsid() FAILED, can\'t start a new session: $!\n" );

# initialize callback signal handlers
$SIG{ INT } = $SIG{ TERM } = $SIG{ HUP } = \&handle_signal;

$SIG{ PIPE } = 'ignore';

# create pid file in /var/run/

start_process_id( $pidFile );


# turn on logging
if ( $loggingOn )
{
   open( LOG, '>>' . $logFile );

   select( ( select( LOG ), $| = 1 )[ 0 ] ); # turn off buffering for log file (set hot filehandles)

   log_entry( $daemonName . ' starting up...' );

   $loggingOn = 2;
}


# attach metric files
if ( defined( $answered_filename ) && ( 0 < length( $answered_filename ) ) )
{
   open( ANSWERED, '>>' . $answered_filename ) or die "cannot open $answered_filename for appending: $!";

   select( ( select( ANSWERED ), $| = 1 )[ 0 ] ); # turn off buffering for answered file (set hot filehandles)
}

if ( defined( $unknown_filename ) && ( 0 < length( $unknown_filename ) ) )
{
   open ( UNKNOWN, '>>' . $unknown_filename ) or die "cannot open $unknown_filename for appending: $!";

   select( ( select( UNKNOWN ), $| = 1 )[ 0 ] ); # turn off buffering for unknown caller file (set hot filehandles)
}


my $modem = new Device::Modem( port => $port );

die "Can\'t connect to port $port!\n" unless $modem->connect( baudrate => $baud );

log_entry( "Established serial connection to $port" );

load_configuration( $config_filename );


# ATI3
# U.S. Robotics 56K FAX USB V1.2.23

$modem->atsend( 'ATI3' . Device::Modem::CR );

my ( $result, @lines ) = $modem->parse_answer();

log_entry( "Model Information:   " . $lines[ 0 ] );


# Init ATs
#$modem->atsend( 'AT S7=60 S0=0 L2 V1 X4 &C1 E1 Q0' . Device::Modem::CR ); # 'Stolen' from minicom :P


# ATI7
# Configuration Profile...
# 
# Product Type           US/Canada USB 
# Product ID:            USR5637
# Options                V32bis,V.80,V.34+,V.90,V.92
# Error Correction       MNP,V.42
# Data Compression       MNP5,V.42bis,V.44
# Fax Options            Class 1
# Line Options           Caller ID
# 
# Flash Date             06/04/2012
# Flash Rev              1.2.23

$modem->atsend( 'ATI7' . Device::Modem::CR );

( $result, @lines ) = $modem->parse_answer();

my $info = "Configuration:\n";

my $i;

for ( $i = 0; $i < $#lines; $i++ )
{
   $info .= '   ' . $lines[ $i ] . "\n";
}

log_entry( $info );

# Enable Caller ID info
$modem->atsend( 'AT#CID=1' . Device::Modem::CR );

$modem->parse_answer();

my $whitelistCall = 0;
my $blacklistCall = 0;
my $unknownCall = 0;

my $ringCount = 0;
my $ignoreCount = 0;

my $caller = "";
my $number = "";

log_entry( "Waiting for call..." );

### Main Event Loop ###
#

while ( !$shutdown )
{
   # listen for incoming RINGs from modem

   my $cid_info = $modem->answer( undef, 10000 );  # 10 second timeout

   if ( defined( $cid_info ) && ( $cid_info eq 'RING' ) )
   {
      $ringCount++;

      $ignoreCount = 0;

      # more general blocking case (after two rings, block by area code)
      if ( $ringCount >= 2 )
      {
         # if $name/$number not in whitelist (unknown)
         if ( !( exists( $whitelist{ $number } ) && defined( $whitelist{ $number } ) ) && !( exists( $whitelist{ $caller } ) && defined( $whitelist{ $caller } ) ) )
         {
            # check area code locality

            check_areacode( $modem, $number, $caller );
         }
      }
   }
   elsif ( defined( $cid_info )
           && ( ( $cid_info =~ /DATE\s*=\s*.*/ ) || ( $cid_info =~ /TIME\s*=\s*.*/ )
                || ( $cid_info =~ /NAME\s*=\s*.*/ ) || ( $cid_info =~ /NMBR\s*=\s*.*/ ) ) )
   {
      # caller-id information received

      $caller = "";
      $number = "";

      my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( time() );

      my $iso8601date = sprintf( "%04d-%02d-%02dT%02d:%02d:%02d", ( $year + 1900 ), ( $mon + 1 ), $mday, $hour, $min, $sec );

      if ( $cid_info =~ /NMBR\s*=\s*([\d\s]+)/ )
      {
         $number = $1;

         $number =~ tr/ //ds;  #remove internal spaces
         $number =~ s/^\s+//;  #trim left
         $number =~ s/\s+$//;  #trim right
      }

      if ( $cid_info =~ /NAME\s*=\s*(.+)/ )
      {
         $caller = $1;

         $caller =~ s/^\s+//;
         $caller =~ s/\s+$//;
      }

      $ringCount++;

      $ignoreCount = 0;

      if ( ( exists( $whitelist{ $number } ) && defined( $whitelist{ $number } ) ) || ( exists( $whitelist{ $caller } ) && defined( $whitelist{ $caller } ) ) )
      {
         $whitelistCall++;
      }
      elsif ( ( exists( $blacklist{ $number } ) && defined( $blacklist{ $number } ) ) || ( exists( $blacklist{ $caller } ) && defined( $blacklist{ $caller } ) ) )
      {
         $blacklistCall++;

         # answer immediately ATA or ATDT?

         print ANSWERED '"' . $iso8601date . '","' . $number . '","' . $caller . '"' . "\n";

         answer_call( $modem );
      }
      else
      {
         $unknownCall++;

         print UNKNOWN '"' . $iso8601date . '","' . $number . '","' . $caller . '"' . "\n";
      }
   }
   else
   {
      $ignoreCount++;

      if ( $ringCount > 0 )
      {
         # reset caller information
         $caller = "";
         $number = "";

         $ringCount = 0;
      }

      select( undef, undef, undef, 0.100 );
   }

   # repeat until shutdown
}

### Exit Program ###
#

END
{
   if ( 2 == $loggingOn )
   {
      my $summary = "Identified " . ( $whitelistCall + $blacklistCall + $unknownCall ) . " total calls ";

      $summary .= "| whitelisted: " . $whitelistCall . " callers | blacklisted: " . $blacklistCall . " callers ";
      $summary .= "| unknown: " . $unknownCall . " callers";

      log_entry( $summary );

      log_entry( $daemonName . ' shutting down...' );

      close( LOG );
   }

   shutdown_process_id( $pidFile );

   close( ANSWERED );
   close( UNKNOWN );

   $modem->disconnect();
}
