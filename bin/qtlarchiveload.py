'''
#
# Purpose:
#
#	To sanity check 
#
# Input:
#
#	A tab-delimited file in the format:
#		field 1: Marker Acc ID
#		field 2: Symbol
#
# Sanity Checks:
#
#        1)  Invalid Line (missing column(s))
#        2)  Symbol must be Official
#
# Output:
#
#	Diagnostics file of all input parameters and SQL commands
#	Error file
#
'''

import sys
import os
import db
import mgi_utils
import loadlib

#
# from configuration file
#
inputFileName = os.environ['INPUT_FILE_DEFAULT']
diagFileName = os.environ['LOG_DIAG']
errorFileName = os.environ['LOG_ERROR']

inputFile = ''		# file descriptor
diagFile = ''		# file descriptor
errorFile = ''		# file descriptor
error = 0

def exit(status, message = None):
    '''
    # requires: status, the numeric exit status (integer)
    #           message (string)
    #
    # effects:
    # Print message to stderr and exits
    #
    # returns:
    #
    '''

    if message is not None:
        sys.stderr.write('\n' + str(message) + '\n')

    if error:
        errorFile.write('\nSanity check failed.  Errors detected.\n')
    else:
        errorFile.write('\nSanity check successful.\n')

    try:
        inputFile.close()
        diagFile.flush()
        errorFile.flush()
        diagFile.write('\n\nEnd Date/Time: %s\n' % (mgi_utils.date()))
        errorFile.write('\nEnd file\n')
        diagFile.close()
        errorFile.close()
    except:
        pass

    sys.exit(status)
 
def init():
    '''
    # requires: 
    #
    # effects: 
    # 1. Processes command line options
    # 2. Initializes local DBMS parameters
    # 3. Initializes global file descriptors/file names
    #
    # returns:
    #
    '''

    global inputFile, diagFile, errorFile
    global errorFileName, diagFileName

    try:
        inputFile = open(inputFileName, 'r')
    except:
        exit(1, 'Could not open file %s\n' % inputFileName)
            
    try:
        diagFile = open(diagFileName, 'w')
    except:
        exit(1, 'Could not open file %s\n' % diagFileName)
            
    try:
        errorFile = open(errorFileName, 'w')
    except:
        exit(1, 'Could not open file %s\n' % errorFileName)
            
    # Log all SQL 
    db.set_sqlLogFunction(db.sqlLogAll)

    # Set Log File Descriptor
    db.set_commandLogFile(diagFileName)

    # Set Log File Descriptor
    diagFile.write('Start Date/Time: %s\n' % (mgi_utils.date()))
    diagFile.write('Server: %s\n' % (db.get_sqlServer()))
    diagFile.write('Database: %s\n' % (db.get_sqlDatabase()))
    diagFile.write('Input File: %s\n' % (inputFileName))
    errorFile.write('\nStart file: %s\n\n' % (mgi_utils.date()))

def processFile():
    '''
    # requires:
    #
    # effects:
    #	Reads input file
    #	Verifies and Processes each line in the input file
    #
    # returns:
    #	nothing
    #
    '''

    global error

    lineNum = 0

    for line in inputFile.readlines():

        lineNum = lineNum + 1

        if lineNum == 1:
            continue

        tokens = str.split(line[:-1], '\t')

        try:
            markerId = tokens[0]
            symbol = tokens[1]
        except:
            errorFile.write('Invalid Line (missing column(s)) (row %d): %s\n' % (lineNum, line))
            error = 1
            continue

        markerKey = loadlib.verifyMarker(markerId, lineNum, errorFile)

        if markerKey == 0:
            errorFile.write(str(tokens) + '\n\n')
            error = 1
            continue

#
# Main
#

init()
processFile()

exit(0)
