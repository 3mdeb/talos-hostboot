#!/usr/bin/env python
# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/build/buildpnor/bpm-utils/insertBpmFwCrc.py $
#
# OpenPOWER HostBoot Project
#
# Contributors Listed Below - COPYRIGHT 2019
# [+] International Business Machines Corp.
#
#
# Copyright (c) 2019 SMART Modular Technologies, Inc.
# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# IBM_PROLOG_END_TAG
import os, sys, time, datetime, glob
from subprocess import Popen, PIPE
import shlex

#
# Function to insert the CRC signature in the
# firmware image file, inFile, and to generate the
# signature file, outFile.
#
def InsertCrcSignature(inFile, outFile):

    #
    # Open the outFile
    #
    try:
        print("\nOpening outFile = %s" % outFile)
        outFileObj = open(outFile, "w")
    except Exception as e:
        print "\nException {0} occured, args: {1!r}".format(type(e).__name__, e.args)
        sys.exit(999)

    #
    # Read from the inFile and copy the data to the outFile.
    #
    # At the right address, insert the SignatureFile data
    # @FF7A
    # AA 55 [Start_Lo] [Start_Hi] [Crc_Lo] [Crc_Hi]
    #
    # generated from the imageCrc tool, to the outFile.
    #
    # The address insertion has to be in the proper ascending order of
    # addresses given in the inFile in to the outFile.
    #
    # For example the outFile should have the following:
    # =================================================
    # ...
    # @8000 / @A000   << The firmware start address is always either one of them.
    # ....
    # ....
    # @FF7A   <<<< The "@" addresses must be in ascending order in the Firmware Image file.
    # AA 55 [Start_Lo] [Start_Hi] [Crc_Lo] [Crc_Hi]
    #
    # ....
    # @FFDA
    # ....

    # Call imageCrc here
    cmd = './imageCrc ' + inFile 
    cmdArgs = shlex.split(cmd)
    proc = Popen(cmdArgs, stdout=PIPE, stderr=PIPE)
    out,err = proc.communicate()
    exitCode = proc.returncode

    if exitCode:
        print "\nCRC generation using imageCrc utility for {0} failed, below are stdout and stderr".format(inFile)
        print "Command stdout - \n{0}".format(out)
        print "Command stderr - \n{0}".format(err)
        sys.exit(999)
    else:
        print "\nCRC generation using imageCrc utility successful" 
        print "Command output - \n{0}".format(out)

    # Parse through output of imageCrc and get addr and signature
    splitLines_crc = out.splitlines()
    for counter in range(0, len(splitLines_crc)):

        if splitLines_crc[counter].startswith("@"):
            crcAddressLine = splitLines_crc[counter].strip()
            crcSignature = splitLines_crc[counter+1].strip().upper()

    # Open infile here
    # Keep reading infile lines, when read address > the address in signature,
    # insert signature there
    try:
        crcWritten = 0
        print("\nOpening inFile = %s and writing to outFile now..." % inFile)
        with open(inFile, "r") as ins:
            #
            # TODO: Have the logic to insert the signature from the
            # SignatureFile inserted at the correct location in the
            # outFile.
            #

            for line in ins:
                if line.startswith("@"):
                    inputFileAddr = line.strip()
                    # If crc already in input file, check if it is equal to calculate value
                    # If equal, write only once, if not equal, write calculated value
                    if crcWritten == 0 and inputFileAddr == crcAddressLine:
                        outFileObj.write(line.strip()+'\n')
                        if ins.next().strip().upper() == crcSignature:
                            print "Correct crc already present at {0} in input file, will skip writing calculated crc again to output file".format(inputFileAddr)
                        else:
                            print "Incorrect crc present at {0} in input file, will write calculated crc {1} to output file".format(inputFileAddr, crcSignature)
                        outFileObj.write(crcSignature+'\n')
                        crcWritten = 1
                        continue
                    # If crc not present, then write calculated value
                    elif crcWritten == 0 and inputFileAddr > crcAddressLine:
                        outFileObj.write(crcAddressLine+'\n')
                        outFileObj.write(crcSignature+'\n')
                        crcWritten = 1
                outFileObj.write(line.strip()+'\n')

    except Exception as e:
        print "\nException {0} occured, args: {1!r}".format(type(e).__name__, e.args)
        sys.exit(999)

    print("\nClosing Files\n")
    outFileObj.close()

## End of insertCrcSignature ######### 


#
# Main
#
if __name__ == '__main__':

    inFile=""
    outFile=""

    if (len(sys.argv) < 3):
        print "\nUsage: %s <IN FILE> <OUT FILE>\n" % sys.argv[0]
        sys.exit(1)
    else:
        #
        # Name of the firmware image file without the signature
        #
        inFile = sys.argv[1]
        if '/' not in inFile:
            inFile = os.getcwd() + '/' + inFile

        if not os.path.exists(inFile) or os.path.getsize(inFile) == 0:
            print "\nInput File {0} does not exist or is zero in size".format(inFile)
        #
        # Name of the firmware image file to be generated with the signature
        # Please check with Mike on the name for this.
        #
        outFile = sys.argv[2]
        if '/' not in outFile:
            outFile = os.getcwd() + '/' + outFile 

        if os.path.exists(outFile):
            print "\nOutput File {0} already exists, will be wiped out if test successful, press CTRL-C in 5s to stop test if needed".format(outFile)
            time.sleep(5)

    
    #
    # Call the function to insert the CRC signature
    #
    InsertCrcSignature(inFile, outFile)
