#!/usr/bin/perl
# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/build/debug/Hostboot/Istep.pm $
#
# OpenPOWER HostBoot Project
#
# Contributors Listed Below - COPYRIGHT 2012,2017
# [+] International Business Machines Corp.
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
#
# IBM_PROLOG_END_TAG
#
# Purpose:  This perl script implements isteps on AWAN.
#
# Procedure:
#	Call hb_Istep twice:
#	1) hb_Istep [--]istepmode
#	    called after loading but before starting HostBoot
#	    this will check to see if the user has set istep mode, if so
#	    it will write the Istep_mode signature to L3 memory to put
#       HostBoot mode into single-step mode (spless).
#       Then it will boot HostBoot until it is ready to receive commands.
#	2) hb_Istep [--]command
#       Submit a istep/substep command for hostboot to run.
#	    Periodically call ::executeInstrCycles() to step through HostBoot.
#	    Checks for status from previous Isteps, and reports status.
#
# Author: Mark Wenning
#
#   DEVELOPER NOTES:
#   Do NOT put prints or printf's in this script!!!
#       simics-debug-framework.pl and simics-debug-framework.py communicate
#       (recvIPCmsg and sendIPCmsg) overstdin and stdout -
#       if you print to STDOUT you will inadvertently send an empty/corrupted
#       "IPC" message to python/simics which will usually cause ugly crashes.
#

#------------------------------------------------------------------------------
# Specify perl modules to use
#------------------------------------------------------------------------------
use strict;
use POSIX;      #   isdigit

## 64-bit input
use bigint;
no  warnings    'portable';


##  declare Istep package
package Hostboot::Istep;
use Exporter;
our @EXPORT_OK = ('main');
use File::Temp ('tempfile');
use Data::Dumper;

#------------------------------------------------------------------------------
#   Constants
#------------------------------------------------------------------------------
##  @todo   extract these from splesscommon.H

use constant    SPLESS_SINGLE_ISTEP_CMD     =>  0x00;
use constant    SPLESS_RESUME_ISTEP_CMD     =>  0x01;
use constant    SPLESS_CLEAR_TRACE_CMD      =>  0x02;

use constant    MAX_ISTEPS                  =>  256;
use constant    MAX_SUBSTEPS                =>  25;

##  Mailbox Scratchpad regs
use constant    MBOX_SCRATCH1               =>  0x00050038;     ## conTrace addr
use constant    MBOX_SCRATCH2               =>  0x00050039;     ## conTrace len
use constant    MBOX_SCRATCH3               =>  0x0005003a;     ## Not used
use constant    MBOX_SCRATCH4               =>  0x0005003b;     ## cmd reg

##  extra parm for ::executeInstrCycles
use constant    NOSHOW                      =>  1;

#------------------------------------------------------------------------------
# Globals
#------------------------------------------------------------------------------
my  $opt_debug          =   0;
my  $opt_splessmode     =   0;
my  $opt_command        =   0;
my  $opt_list           =   0;
my  $opt_resume         =   0;
my  $opt_clear_trace    =   0;

my  $command            =   "";

my  @inList;


my  $THREAD         =   "0";

my $g_attr_fname = "";
my $g_attr_fh;



##  --------------------------------------------------------------------------
##  get any environment variables
##  --------------------------------------------------------------------------

##  @todo   make this an enviroment var?
##  NOTE:  this is the # cycles used for simics, it is multiplied by 100
##  in vpo-debug-framework.pl
my  $hbDefaultCycles    =   5000000;

my  $hbCount =   $ENV{'HB_COUNT'};
if ( !defined( $hbCount ) || ( $hbCount eq "" ) )
{
    ##  set default
    $hbCount    =   0x2ff;     ##  default that should work for all env
}

## init global variables
my  $ShutDownFlag   =   "";
my  $ShutDownSts    =   "";




########################################################################
##  MAIN ROUTINE, called from debug framework
########################################################################
sub main
{
    ##  $packName is the name of the selected tool
    ##  $args is a hashref to all the command-line arguments
    my ($packName,$args) = @_;


    ##  debug - save
    while ( my ($k,$v) = each %$args )
    {
        ::userDisplay "args: $k => $v\n";
    }

    ::userDisplay   "Welcome to hb-Istep 3.34 .\n";
    ::userDisplay   "Note that in simics, multiple options must be in quotes,";
    ::userDisplay   "separated by spaces\n\n";

    ##  initialize inList to "undefined"
    $inList[MAX_ISTEPS][MAX_SUBSTEPS]   =   ();
    for( my $i = 0; $i <    MAX_ISTEPS; $i++)
    {
        for(my $j = 0; $j < MAX_SUBSTEPS; $j++)
       {
            undef( $inList[$i][$j] );
        }
    }

    ##  ---------------------------------------------------------------------------
    ##  Fetch the symbols we need from syms file
    ##  ---------------------------------------------------------------------------

    $ShutDownFlag   =   getSymbol(  "CpuManager::cv_shutdown_requested" );
    $ShutDownSts    =   getSymbol(  "CpuManager::cv_shutdown_status" );

    ##  fetch the istep list
    get_istep_list();

    ##  debug, dump all the environment vars that we are interested in
    ## dumpEnvVar( "HB_TOOLS" );
    ## dumpEnvVar( "HB_IMGDIR" );
    ## dumpEnvVar( "HB_VBUTOOLS" );
    ## dumpEnvVar( "HB_COUNT" );

    ##--------------------------------------------------------------------------
    ##  Start processing options
    ##  process the "flag" standard options, then use a loop to go through
    ##  the rest
    ##--------------------------------------------------------------------------
        ##  Get all the command line options in an array
    my  @options    =   ( keys %$args );
    ## ::userDisplay   join( ' ', @options );

    if  ( !(@options) )
    {
        ::userDisplay "type \"help hb-istep\" for help\n";
        exit;
    }

    ##
    ##  find all the standard options, set their flag, and remove them from
    ##  the options list.
    ##  vpo and simics use different command-line styles:
    ##  simics wants you to say " hb-istep "debug s4" ",
    ##  (note that multiple options must be in quotes, separated by spaces)
    ##  and vpo wants you to say "hb-istep --debug --command s4" .
    ##  This should accept both styles.
    ##
    for ( my $i=0; $i <= $#options; $i++ )
    {
        $_  =   $options[$i];

        ## ::userDisplay ".$_.";

        if ( m/^\-{0,2}help$/ )
        {
            showHelp();
            exit
        }
        if ( m/^\-{0,2}debug$/ )
        {
            $opt_debug      =   1;
            $options[$i]    =   "";
        }
        if ( m/^\-{0,2}list$/ )
        {
            $opt_list       =   1;
            $options[$i]    =   "";
        }
        if ( m/^\-{0,2}splessmode$/ )
        {
            $opt_splessmode  =   1;
            $options[$i]    =   "";
        }
        if ( m/^\-{0,2}command$/ )
        {
            ## doesn't do much, just eats the option
            $opt_command    =   1;
            $options[$i]    =   "";
        }
        if ( m/^\-{0,2}resume$/ )
        {
            $opt_resume     =   1;
            $options[$i]    =   "";
        }
        if  ( m/^\-{0,2}clear-trace$/ )
        {
            $opt_clear_trace    =   1;
            $options[$i]    =   "";
        }
    }   ##  endfor

    ##  if there's anything left after this, assume it is a single command
    $command  = join( "", @options );
    chomp $command;

    ##  print out debug info
    if  ( $opt_debug )
    {
        ::userDisplay   "\n-----    DEBUG:  ------------------------------- \n";
        ::userDisplay   "debug          =   $opt_debug\n";
        ::userDisplay   "list           =   $opt_list\n";
        ::userDisplay   "splessmode     =   $opt_splessmode\n";

        ::userDisplay   "resume         =   $opt_resume\n";
        ::userDisplay   "clear-trace    =   $opt_clear_trace\n";
        ::userDisplay   "command flag   =   $opt_command\n";
        ::userDisplay   "command        =   \"$command\"\n";

        ::userDisplay   "ShutDownFlag   =   ", sprintf("0x%x",$ShutDownFlag), "\n";
        ::userDisplay   "ShutDownSts    =   ", sprintf("0x%x",$ShutDownSts),  "\n";

        ::userDisplay   "hbCount        =   ", sprintf("0x%x",$hbCount),      "\n";

        ::userDisplay   "\n";
    }

    if ( $opt_debug )   {   ::userDisplay   "=== check ShutDown Status...\n";  }
    if ( isShutDown() )
    {
        ::userDisplay   "Shutdown detected: cannot run HostBoot.\n";
        exit;
    }

    ##  ----------------------------------------------------------------
    ##  finally, run some commands.
    ##  ----------------------------------------------------------------

    if ( $opt_list  )
    {
        ::userDisplay   "List isteps\n";
        print_istep_list();
        exit;
    }

    if ( $opt_splessmode )
    {
        ::userDisplay   "ENable splessmode\n";
        setMode( "spless" );
        ::userDisplay   "Done.\n";
        exit;
    }

    ##  don't do any other commands unless ready bit is on.
    if ( ! isReadyBitOn() )
    {
        ::userDisplay   "Ready bit is off, must run splessmode first.\n";
        exit 1;
    }

    if ( $opt_clear_trace )
    {
        ::userDisplay   "Clear Trace\n";
        clear_trace();
        exit;
    }

    if ( $opt_resume )
    {
        ::userDisplay   "Resume\n";
        resume_istep();
        exit;
    }

    if ( $opt_command || ( $command ne "" ) )
    {
        ::userDisplay   "Process command \"$command\"\n";
        process_command( $command );
        exit;
    }

    ::userDisplay   "Done.\n";
    exit    0;
}   ##  end main

########################################################################
##  SUBROUTINES
########################################################################
##


sub helpInfo
{
    my %info = (
        name => "Istep",
        intro => ["Executes isteps."],
        options => {    "list"          =>  [" list out all supported isteps "],
                        "splessmode"    =>  ["enable istep mode"],
                        "resume"        =>  ["resume an istep that is at a break point"],
                        "clear-trace"   =>  ["clear trace buffers before starting"],
                        "sN"            =>  ["run istep N"],
                        "sN..M"         =>  ["run isteps N through M"],
                        "<foo>"         =>  ["run named istep \"foo\""],
                        "<foo>..<bar>"  =>  ["run named isteps \"foo\" through \"bar\""],
                   }
    );
}

sub showHelp
{
    ::userDisplay "Executes isteps.\n";
    ::userDisplay "Options =>\n";
    ::userDisplay "          list =>  list out all supported isteps\n";
    ::userDisplay "        resume =>  resume an istep at a break point\n";
    ::userDisplay "   clear-trace =>  clear trace buffers before starting\n";
    ::userDisplay "            sN =>  run istep N\n";
    ::userDisplay "         sN..M =>  run isteps N through M\n";
    ::userDisplay "         <foo> =>  run named istep \"foo\"\n";
    ::userDisplay "  <foo>..<bar> =>  run isteps \"foo\" through \"bar\"\n";

    exit 0;
}

##  ---------------------------------------------------------------------------
##  Check to see if there are debug bufs avail avail
##  if so, extract type and call correct subroutine to handle
##  ---------------------------------------------------------------------------
sub checkDebugBuf
{
    my  $SCRATCH_MBOX1  =   0x00050038;
    my  $SCRATCH_MBOX2  =   0x00050039;
    my  $MSG_TYPE_MASK  =   0xFF00000000000000;
    my  $MSG_TYPE_TRACE =   0x0000000000000000;
    my  $MSG_TYPE_ATTR  =   0x0100000000000000;
    my  $dbgAddr      =   "";
    my  $dbgSize      =   "";

    $dbgAddr  =   ::readScom( $SCRATCH_MBOX1, 8 );
    if ( $dbgAddr != 0  )
    {
        #There is something to do.  Get the dbgSize to determine the type
        $dbgSize  =   ::readScom( $SCRATCH_MBOX2, 8 );

        #contTrace has the buffer, address MBOX_SCRATCH2 has size
        #MBOX Scratch regs are only valid from 0:31, shift to give a num
        my $buffAddr = $dbgAddr  >> 32;
        my $buffSize = ($dbgSize & (~$MSG_TYPE_MASK)) >> 32;
        my $msgType = $dbgSize & $MSG_TYPE_MASK;

        #::userDisplay   ".";
        #::userDisplay   "DebugBuf addr[", sprintf("0x%x", $buffAddr),
        #                "] type[", sprintf("0x%x", $msgType),
        #                "] size[" , sprintf("0x%x",$buffSize), "]\n";

        if ($msgType == $MSG_TYPE_TRACE)
        {
            handleContTrace($buffAddr, $buffSize);
        }
        elsif ($msgType == $MSG_TYPE_ATTR)
        {
            handleAttrDump($buffAddr, $buffSize);
        }

        #Write 0 to let HB know we extracted buf and it can continue
        ::writeScom($SCRATCH_MBOX1, 8, 0x0);
    }
}

##  ---------------------------------------------------------------------------
##  Check to see if there are trace buffers avail
##  if so, extract and write them out
##  ---------------------------------------------------------------------------
sub handleContTrace
{
    my  $buffAddr      =   shift;
    my  $buffSize      =   shift;
    my  $ctName         =   "tracMERG.cont";

    my $fh;
    my $fname;
    my  $contFile;
    ($fh,$fname) = tempfile();
    open ($contFile, '>>', $ctName) or die "Can't open '$ctName' $!";
    binmode($fh);

    print $fh (::readData($buffAddr, $buffSize));

    open TRACE, ("fsp-trace -s ".::getImgPath().
                 "hbotStringFile $fname |") || die;
    while (my $line = <TRACE>)
    {
        ::userDisplay $line;
        print $contFile $line;
    }

    unlink $fname;
}


##  ---------------------------------------------------------------------------
##  Extract an ATTR dump bin, when complete, call tool to parse.
##  ---------------------------------------------------------------------------
sub handleAttrDump
{
    my  $buffAddr      =   shift;
    my  $buffSize      =   shift;
    my  $txtName         =   "hbAttrDump.txt";

    #If there is an empty filename, need to create one, otherwise just append
    if ($g_attr_fname eq "")
    {
        ($g_attr_fh,$g_attr_fname) = tempfile();
        binmode($g_attr_fh);
    }

    # Check to see if magic "done" address has been sent,
    # if so call tool to parse
    if ($buffAddr == 0xFFFFCAFE)
    {
        #::userDisplay "Got done, processing bin file[$g_attr_fname]\n";
        close $g_attr_fh ;

        ##Call the FapiAttr tool module
        $Hostboot::_DebugFramework::toolOpts{'attrbin'} = $g_attr_fname;
        ::callToolModule("FapiAttr");

        unlink $g_attr_fname;
        $g_attr_fname = "";

    }
    else # Write data to bin temp file
    {
        print $g_attr_fh (::readData($buffAddr, $buffSize));
    }
}


##  ---------------------------------------------------------------------------
##  Dump environment variable specified.
##  ---------------------------------------------------------------------------
sub dumpEnvVar( $ )
{
    my  $envvar =   shift;

    if ( defined( $ENV{$envvar} )  )
    {
        ::userDisplay "$envvar =   $ENV{$envvar}\n";
    }
}

##
##  Get symbol address from hbotSymsFile
##
sub getSymbol( )
{
    my  $symbol  =   shift;
    my ($symAddr, $symSize) = ::findSymbolAddress( $symbol ) ;

    if ( not defined( $symAddr ) )
    {
        ::userDisplay "Cannot find $symbol.\n"; die;
    }

    return  $symAddr;
}

##
##  read in file with csv istep list and store in inList
##
sub get_istep_list()
{
    my $istep, my $substep, my $name ;

    my  @isteplist  =   ::getIstepList();

    ##  DEBUG:  Comment in to test invalid minor and invalid major isteps
    ## $inList[7][8]   =   "invalid_minor";
    ## $inList[0][17]  =   "invalid_major";

    foreach( @isteplist )
    {
        chomp;

        ( $istep, $substep, $name) =   split( ",", $_ );
        chomp $name;

        ## ::userDisplay "$_, $istep, $substep, $name\n" ;

        if ( defined($name) && ( $name ne "" ) )
        {
            $inList[$istep][$substep]    =   $name;
        }
    }

}


##
##  print the istep list to the screen.
##
sub print_istep_list( )
{
    my  $hdrflag    =   1;

    ## ::userDisplay   " IStep Name\n";
    ##::userDisplay   "---------------------------------------------------\n";

    for( my $i = 4; $i < MAX_ISTEPS; $i++)
    {
        for( my $j = 0; $j < MAX_SUBSTEPS; $j++)
        {
            ## print all substeps
            if ( defined( $inList[$i][$j] ) )
            {
                if ( $hdrflag )
                {
                    ::userDisplay   " ----- IStep $i -----  \n";
                    $hdrflag = 0;
                }
                ## will truncate after 40 chars, hopefully this will not be an issue
                my $ss  =   sprintf( "%-40s", $inList[$i][$j] );
                ::userDisplay   "$i.$j: $ss\n" ;
            }
        }   ## end for $j

        $hdrflag=1;
    }   ##  end for $i
}


##
##  Find istep name in inList array.
##
##  @param[in]  -   name
##
##  @return     -   istep #, substep #, found flag = true for success
##                                                   false for not found
##
sub find_in_inList( $ )
{
    my  ( $substepname )    =   @_;

    for(my $i = 0; $i < MAX_ISTEPS; $i++)
    {
        for(my $j = 0; $j < MAX_SUBSTEPS; $j++)
        {
            if ( defined($inList[$i][$j]) && ($inList[$i][$j] eq $substepname ) )
            {
                return  ($i, $j, 1 );
            }
        }
    }

    return ( MAX_ISTEPS, MAX_SUBSTEPS, 0 )
}

##
##  When HostBoot goes into singlestep mode, it turns on the ready bit in the
##  status reg.
##
##  @return nonzero if ready bit is on, else 0
##
sub isReadyBitOn()
{
    my  $result     =   0;
    my  $readybit   =   0;

    $result = getStatus( );
    $readybit    =   ( ( $result & 0x8000000000000000 ) >> 63 );

    if ( $opt_debug )   {   ::userDisplay   "=== readybit: $readybit\n";    }

    if ( $readybit )
    {
        return  1;
    }

    return  0;
}




##
##  Check if HostBoot has already run and shutdown.
##
##  @return nonzero if it has, 0 otherwise
##
sub isShutDown()
{

    my $flag    =   ::read64( $ShutDownFlag );
    my $status  =   ::read64( $ShutDownSts  );

    if ( $opt_debug )
    {
        ::userDisplay "=== isShutDown : Shutdown Flag   =   $flag\n";
        ::userDisplay "=== isShutDown : Shutdown Status = ",
                      sprintf( "0x%x", $status), "\n";
    }

    if ( $flag )
    {
        ::userDisplay "HostBoot has shut down with status ",
                      sprintf( "0x%x", $status), ".\n";
        return 1;
    }

    return 0;
}

##  --------------------------------------------------------------------
##  Write command reg
##
##  @param[in]  -   HEX STRING containing the 64-bit command word
##
##  @return none
##
##  --------------------------------------------------------------------
sub sendCommand( $ )
{
    my  $data    =   shift;
    my  $read_bindata;

    if ( $opt_debug )
        {   ::userDisplay "===  sendCommand( $data )\n";    }

    ## because of the way the SIO regs work on the BMC,
    ## Hostboot expects a key to be set to trigger the command
    ## when doing via scom we simply need to read, modify write
    ## the reg
    $read_bindata = ::readScom( MBOX_SCRATCH4, 8 );
    my $key = (($read_bindata) & 0x1F00000000000000);

    ## convert to binary before sending to writescom
    my  $bindata    =   ( hex $data );

    ## Or in key
    my $bindata = (($bindata) & 0xE0FFFFFFFFFFFFFF);
    $bindata = (($bindata) | ($key));

    ## now write the data
    ::writeScom( MBOX_SCRATCH4, 8, $bindata );

    if ( $opt_debug )
    {
        ## sanity check
        ::executeInstrCycles( 10, NOSHOW );
        my $readback    =   ::readScom( MBOX_SCRATCH4, 8 );
        ::userDisplay   "=== sendCommand readback: $readback\n";
    }

}


##  --------------------------------------------------------------------
##  read status reg
##
##  Note - mbox scratchpad regs are only 32 bits, so HostBoot will return
##  status in mbox 2 (hi32 bits) and mbox 1 (lo32 bits).
##  mbox 0 is reserved for continuous trace.
##
##
##
##  @return     binary  64-bit value
##  --------------------------------------------------------------------
sub getStatus()
{
    my  $status     =   0;
    my  $statusHi   =   "";
    my  $statusLo   =   "";

    $statusHi   =   ::readScom( MBOX_SCRATCH4, 8 );
    if ( $opt_debug )   {   ::userDisplay   "===  statusHi: $statusHi \n";  }

    $statusLo   =   0;

    $status =   ( ( $statusHi) & 0xffffffff00000000 );

    if ( $opt_debug )
    {
        ::userDisplay   "===  getStatus() returned ", (sprintf( "0x%lx", $status ) ), "\n";
    }

    return  $status;
}


##
##  keep trying to get status until readybit turns back on
##
sub getSyncStatus( )
{
    # set # of retries
    my  $count          =   $hbCount ;
    my  $result         =   0;
    my  $running        =   0;
    my  $ready          =   0;

    ##  get response
    while(1)
    {

        ##  advance HostBoot code by a certain # of cycles, then check the
        ##  sequence number to see if it has changed.  rinse and repeat.
        ::executeInstrCycles( $hbDefaultCycles, NOSHOW );


        ##  check to see if we need to dump trace - no-op in simics
        checkDebugBuf();

        $result     = getStatus();
        $running    =   ( ( $result & 0x2000000000000000 ) >> 61 );
        $ready      =   ( ( $result & 0x8000000000000000 ) >> 63 );


        ## @todo great place to add some debug, check running bit BEFORE
        ##  starting the clock (should be off), then run (relatively) small
        ##  number of clocks till the bit turns on.
        ##  Wait for the readybit to turn back on
        if ( $ready )
        {
            return $result;
        }

        if ( $count <= 0)
        {
            ::userDisplay   "TIMEOUT waiting for readyBit to assert again\n";
            return -1;
        }

        $count--;

    }   ##  endwhile

}


##
##  Run an istep
##
sub runIStep( $$ )
{
    my  ( $istep, $substep)  = @_;
    my  $byte0, my $command;
    my  $cmd;
    my  $result;


    ::userDisplay   "run  $istep.$substep $inList[$istep][$substep]:\n" ;

    $byte0   =   0x40;      ## gobit
    $command =   SPLESS_SINGLE_ISTEP_CMD;
    $cmd = sprintf( "0x%2.2x%2.2x%2.2x%2.2x00000000", $byte0, $command, $istep, $substep );

    sendCommand( $cmd );

    $result  =   getSyncStatus();

    ## if result is -1 we have a timeout
    if ( $result == -1 )
    {
        ::userDisplay   "-----------------------------------------------------------------\n";
        exit 1;
    }
    else
    {
        my $taskStatus  =   ( ( $result & 0x00FF000000000000 ) >> 48 );
        my $stsIStep    =   ( ( $result & 0x0000ff0000000000 ) >> 40 );
        my $stsSubstep  =   ( ( $result & 0x000000ff00000000 ) >> 32 );

        ::userDisplay "---------------------------------\n";
        if ( $taskStatus != 0 )
        {
            ::userDisplay   "Istep $stsIStep.$stsSubstep FAILED , task status is $taskStatus, check error logs\n" ;
            exit 1;
        }
        else
        {
            ::userDisplay   "Istep $stsIStep.$stsSubstep $inList[$istep][$substep] returned Status: ",
                            sprintf("%x",$taskStatus),
                            "\n" ;
            if ( $taskStatus == 0xa )
            {
                ::userDisplay   ":     not implemented yet.\n";
            }
            elsif ( $taskStatus != 0 )
            {
                exit 1;
            }
        }
    }
}

##
##  run command = "sN"
##
sub sCommand( $ )
{
    my  ( $scommand )   =   @_;

    my  $i   =   $scommand;
    my  $j   =   0;

    #   execute all the substeps in the IStep
    for( $j=0; $j<MAX_SUBSTEPS; $j++ )
    {


        if ( defined( $inList[$i][$j] ) )
        {
            runIStep( $i, $j );
        }
    }
}


##
##  parse --command [command] option and execute it.
##
sub process_command( $ )
{
    my  ( $command ) =   @_;
    my  @execlist;
    my  $istepM, my $substepM, my $foundit, my $istepN, my $substepN;
    my  $M, my $N, my $scommand;
    my  @ss_list;

    ## check to see if we have an 's' command (string starts with 's' and a number)
    chomp( $command);
    if ( $command =~ m/^s+[0-9].*/ )
    {
        ## run "s" command
        if ($opt_debug) {   ::userDisplay   "=== s command \"$command\" \n";   }
        substr( $command, 0, 1, "" );

        if ( POSIX::isdigit($command) )
        {
            # command = "sN"
            if ($opt_debug) {   ::userDisplay   "=== single IStep: ", $command, "\n";  }
            sCommand( $command );
        }
        else
        {
            #   list of substeps = "sM..N"
            ( $M, $N )  =   split( /\.\./, $command );

            if ($opt_debug) {   ::userDisplay   "=== multiple ISteps: ", $M, "-", $N, "\n";    }
            for ( my $x=$M; $x<$N+1; $x++ )
            {
                sCommand( $x );
            }
        }
    }
    else
    {
        ## <substep name>, or <substep name>..<substep name>
        @ss_list    =   split( /\.\./, $command );

        if ($opt_debug) {   ::userDisplay   "=== named commands : ", @ss_list, "\n";    }

        ( $istepM, $substepM, $foundit) = find_in_inList( $ss_list[0] );
        $istepN      =   $istepM;
        $substepN    =   $substepM;
        if ( ! $foundit )
        {
            ::userDisplay   "Invalid substep ", $ss_list[0], "\n" ;
            return -1;
        }


        if ( $#ss_list > 0 )
        {
            ( $istepN, $substepN, $foundit) = find_in_inList( $ss_list[1] );
            if ( ! $foundit )
            {
                ::userDisplay   "Invalid substep $ss_list[1] \n" ;
                return -1;
            }
        }

        for(my $x=$istepM; $x<=$istepN; $x++)
        {
            if ($istepM == $istepN)
            {
                # First and Last Steps are the same.
                # Run all requested substeps between the same step
                for(my $y=$substepM; $y<=$substepN; $y++)
                {
                    if (defined($inList[$x][$y]))
                    {
                        runIStep($x, $y);
                    }
                }
            }
            elsif ($x == $istepM)
            {
                # First requested Step, run from requested substep
                for(my $y=$substepM; $y<MAX_SUBSTEPS; $y++)
                {
                    if (defined($inList[$x][$y]))
                    {
                        runIStep($x, $y);
                    } 
                }
            }
            elsif ($x == $istepN)
            {
                # Last requested Step, run up to requested substep
                for(my $y=0; $y<=$substepN; $y++)
                {
                    if (defined($inList[$x][$y]))
                    {
                        runIStep($x, $y);
                    }
                }
            }
            else
            {
                # Middle istep, run all substeps
                for(my $y=0; $y<MAX_SUBSTEPS; $y++)
                {
                    if (defined($inList[$x][$y]))
                    {
                        runIStep($x, $y);
                    }
                }
            }
        }

    }
}


##
##  write to mem to set istep or normal mode, check return status
##
##  Note that this only happens once at the beginning, when "splessmode"
##  is run.
##
sub setMode( $ )
{
    my  ( $cmd )    =   @_;
    my  $count      =   0;
    my  $readybit   =   0;
    my  $result     =   0;

    if ( $cmd eq "spless" )
    {
        ::userDisplay  "This command doesn't force HB into SPLESS mode anymore\n";
        ::userDisplay  "It only establish SPLESS communication (clocks model in sim)\n";
        ::userDisplay  "Use attributes to enter SPLESS mode\n";
        ::userDisplay  "\tSP_FUNCTIONS:mailboxEnabled = 0b0\n";
        ::userDisplay  "\tISTEP_MODE = 0x1\n";
        ::userDisplay  "\n WAITING for readybit to come on";
    }
    else
    {
        ::userDisplay   "invalid setMode command: $cmd\n" ;
        return  -1;
    }

    ##  Loop, advancing clock, and wait for readybit
    $count  =   $hbCount ;
    while(1)
    {

        if ( $opt_debug )   {   ::userDisplay   "=== executeInstrCycles( $hbDefaultCycles )\n"; }
        ##  advance HostBoot code by a certain # of cycles, then check the
        ##  sequence number to see if it has changed.  rinse and repeat.
        ::executeInstrCycles( $hbDefaultCycles, NOSHOW );

        if ( $opt_debug )   {   ::userDisplay   "=== checkDebugBuf\n";   }
        ## check to see if it's time to dump trace - no-op in simics
        checkDebugBuf();

        if ( $opt_debug )   {   ::userDisplay   "=== isShutDown\n";       }
        ## check for system crash
        if ( isShutDown( ) )
        {
            ::userDisplay  "Shutdown detected: cannot run HostBoot.\n";
            return -1;
        }

        if ( $opt_debug )   {   ::userDisplay   "=== isReadyBitOn\n";     }
        if ( isReadyBitOn() )
        {
            ::userDisplay   "READY!\n";
            return  0;
        }
        else
        {
            ::userDisplay   ".";
        }

        if ( $count <= 0 )
        {
            ::userDisplay "TIMEOUT waiting for readybit, status=$result\n" ;
            return -1;
        }

        $count--;

        if ( $opt_debug )   {   ::userDisplay   "=== count = $count\n";     }
    }
}


sub resume_istep()
{
    my $byte0;
    my $command;
    my $cmd;
    my $result;


    ::userDisplay   "resume istep\n";

    $byte0 = 0x40 ;      ## gobit
    $command = SPLESS_RESUME_ISTEP_CMD;
    $cmd = sprintf( "0x%2.2x%2.2x000000000000", $byte0, $command );
    sendCommand( $cmd );

    $result = getSyncStatus();

    ## if result is -1 we have a timeout
    if ( $result == -1 )
    {
        ::userDisplay   "-----------------------------------------------------------------\n";
    }
    else
    {
        my $taskStatus  =   ( ( $result & 0x00FF000000000000 ) >> 48 );

        ::userDisplay   "-----------------------------------------------------------------\n";
        if ( $taskStatus != 0 )
        {
            # This probably means istep was not at a breakpoint.
            ::userDisplay   "resume istep FAILED, task status is $taskStatus\n", $taskStatus ;
        }
        else
        {
            ::userDisplay   "resume istep returned success\n" ;
        }
        ::userDisplay   "-----------------------------------------------------------------\n";
    }
}

sub clear_trace( )
{
    my  $byte0, my $command;
    my  $cmd;
    my  $result;


    $byte0   =   0x40;      ## gobit
    $command =   SPLESS_CLEAR_TRACE_CMD;
    $cmd = sprintf( "0x%2.2x%2.2x%2.2x%2.2x00000000", $byte0, $command, 0, 0 );
    sendCommand( $cmd );

    $result  =   getSyncStatus();

    ## if result is -1 we have a timeout
    if ( $result == -1 )
    {
        ::userDisplay   "-----------------------------------------------------------------\n";
    }
    else
    {
        my $taskStatus  =   ( ( $result & 0x00FF000000000000 ) >> 48 );

        ::userDisplay   "-----------------------------------------------------------------\n";
        if ( $taskStatus != 0 )
        {
            ::userDisplay   "Clear Trace FAILED, task status is taskStatus\n" ;
        }
        else
        {
            ::userDisplay   "Clear Trace returned Status: $taskStatus\n" ;
        }
        ::userDisplay   "-----------------------------------------------------------------\n";
    }
}

  # A Perl module must end with a true value or else it is considered not to
  # have loaded.  By convention this value is usually 1 though it can be
  # any true value.  A module can end with false to indicate failure but
  # this is rarely used and it would instead die() (exit with an error).
  1;

__END__

