#!/usr/bin/perl
# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/build/debug/Hostboot/Dump.pm $
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

use strict;

package Hostboot::Dump;
use Exporter;
our @EXPORT_OK = ('main');

use Fcntl qw(SEEK_SET);

use constant    MEMSTATE_NO_MEM => 0x0;
use constant    MEMSTATE_HALF_CACHE => 0x4;
use constant    MEMSTATE_REDUCED_CACHE => 0x8;
use constant    MEMSTATE_FULL_CACHE => 0xa;
use constant    MEMSTATE_MS_32MEG => 0x20;

use constant    _KB => 1024;
use constant    _MB => 1024 * 1024;

# Size of HBB PNOR partition without ECC, page algined down, minus 4K header
use constant    MAX_HBB_SIZE => (904 * _KB);

# Map the available memory at each state.
# *** NOTE: Keep in sync with fsp-memdump.sh and bootloaderif.H (MAX_HBB_SIZE)
our %memory_maps = (
    MEMSTATE_NO_MEM() =>
        # No memory has been initialized so we can only dump our static
        # code load up to HBB size
        [ 0,                            MAX_HBB_SIZE
        ],
    MEMSTATE_HALF_CACHE() =>
        # All of the first 4MB can now be read.
        [ MAX_HBB_SIZE,                 ((1 * _MB) - MAX_HBB_SIZE),
          1 * _MB,                      1 * _MB,
          2 * _MB,                      1 * _MB,
          3 * _MB,                      1 * _MB
        ],
    MEMSTATE_REDUCED_CACHE() =>
        # Initial chips may have 2MB bad cache
        [ 4 * _MB,                      1 * _MB,
          5 * _MB,                      1 * _MB,
          6 * _MB,                      1 * _MB,
          7 * _MB,                      1 * _MB
        ],
    MEMSTATE_FULL_CACHE() =>
        # Full cache is 10MB
        [ 8 * _MB,                      1 * _MB,
          9 * _MB,                      1 * _MB
        ],
    MEMSTATE_MS_32MEG() =>
        # Add next 22MB after we expand to memory.
        [ 10 * _MB,                      22 * _MB
        ]
);

# Map the current state to the combined states available.
our %memory_states = (
    MEMSTATE_NO_MEM() => [ MEMSTATE_NO_MEM ],
    MEMSTATE_HALF_CACHE() => [ MEMSTATE_NO_MEM,
                             MEMSTATE_HALF_CACHE ],
    MEMSTATE_REDUCED_CACHE() =>
                             [ MEMSTATE_NO_MEM,
                             MEMSTATE_HALF_CACHE, MEMSTATE_REDUCED_CACHE ],
    MEMSTATE_FULL_CACHE() => [ MEMSTATE_NO_MEM,
                             MEMSTATE_HALF_CACHE, MEMSTATE_REDUCED_CACHE,
                             MEMSTATE_FULL_CACHE ],
    MEMSTATE_MS_32MEG() => [ MEMSTATE_NO_MEM,
                             MEMSTATE_HALF_CACHE, MEMSTATE_REDUCED_CACHE,
                             MEMSTATE_FULL_CACHE, MEMSTATE_MS_32MEG ]
);

sub main
{
    my ($packName,$args) = @_;

    # Parse 'debug' option.
    my $debug = 0;
    if (defined $args->{"debug"})
    {
        $debug = 1;
    }

    # Check for a different output directory
    my $outdir = "./";
    if (defined $args->{"outdir"})
    {
        $outdir = $args->{"outdir"};
    }

    # Read the current memory state.
    my $memstate_addr = ::read64(0x2000 + 0x8); # Read descriptor address.
    $memstate_addr += 0x10; # Memory state is 3rd entry into descriptor.
    my $memstate = ::read32($memstate_addr + 4);  # only need bottom 32 bits
    ::userDisplay (sprintf "Current state is %x\n", $memstate) if $debug;

    #Get current timestamp and open a corresponding file.
    my $timeStamp = `date +%Y%m%d%H%M`;
    chomp $timeStamp;
    my $hbDumpFile = "$outdir\hbdump.$timeStamp";

    ::userDisplay "Dumping Hostboot to $hbDumpFile\n";
    open( OUTFH, ">$hbDumpFile" )   or die "can't open $hbDumpFile: $!\n";
    binmode(OUTFH);

    # Read memory regions and output to file.
    foreach my $state (@{$memory_states{int $memstate}})
    {
        my $regions = $memory_maps{int $state};

        while (scalar(@{$regions}))
        {
            my $start = shift @{$regions};
            my $length = shift @{$regions};
            ::userDisplay (sprintf "\t%x@%x\n", $length, $start) if $debug;

            my $data = ::readData($start, $length);
            seek OUTFH, $start, SEEK_SET;
            print OUTFH $data;
        }
    }

    # Close file.
    close OUTFH;

    #Check if hbDumpFile exists and is not empty
    if (-s "$hbDumpFile" )
    {
        ::userDisplay "\nHostBoot dump saved to $hbDumpFile.\n";
        ::userDisplay "Use the hb-dump-debug program to parse the dump.\n";
    }
    else
    {
        ::userDisplay "\nWARNING: Cannot dump HB.  Did you stop instructions?\n\n";
        unlink $hbDumpFile;
    }
}

sub helpInfo
{
    my %info = (
        name => "Dump",
        intro => ["Dumps the entire Hostboot buffer to a file."],
        options => {
                    "outdir=<path>" =>  ["Output directory for dump file"],
                    "debug" => ["More debug output."],
                   },
    );
}
