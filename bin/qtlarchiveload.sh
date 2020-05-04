#!/bin/sh
#
#  qtlarchiveload.sh
###########################################################################
#
#  Purpose:
# 	This script runs the Nomenclature & Mapping load
#
  Usage=qtlarchiveload.sh
#
#  Env Vars:
#
#      See the configuration file qtlarchiveload.config
#
#  Inputs:
#
#      - configuration file - qtlarchiveload.config
#      - input file - see qtlarchiveload.config
#
#  Outputs:
#
#      - An archive file
#      - Log files defined by the environment variables ${LOG_PROC},
#        ${LOG_FILE}, ${LOG_FILE_CUR}, ${LOG_FILE_VAL}, ${LOG_ERROR}
#      - qtlarchiveload logs and bcp file to ${OUTPUTDIR}
#      - Records written to the database tables
#      - Exceptions written to standard error
#
#  Exit Codes:
#
#      0:  Successful completion
#      1:  Fatal error occurred
#
#  Assumes:  Nothing
#
#      This script will perform following steps:
#
#      1) Validate the arguments to the script.
#      2) Source the configuration file to establish the environment.
#      3) Verify that the input files exist.
#      4) Initialize the log file.
#      5) Determine if the input file has changed since the last time that
#         the load was run. Do not continue if the input file is not new.
#      6) Load qtlarchiveload using configuration file
#      7) Archive the input file.
#      8) Touch the "lastrun" file to timestamp the last run of the load.
#
# History:
#
# lec	09/28/2015
#	- new (using qtlarchiveload as a template)
#

cd `dirname $0`

#
# Verify and source the configuration file
#
CONFIG_FILE=$1
. ${CONFIG_FILE}

rm -rf ${LOG_FILE} ${LOG_PROC} ${LOG_DIAG} ${LOG_CUR} ${LOG_VAL} ${LOG_ERROR}

#
# use user-provied value or use config/default value
# Make sure the input file exists (regular file or symbolic link).
#
if [ $# -eq 2 ] 
then
    INPUT_FILE_DEFAULT=$2
fi
if [ ! -r ${INPUT_FILE_DEFAULT} ]
then
    echo "Missing input file: ${INPUT_FILE_DEFAULT}" | tee -a ${LOG_FILE}
    exit 1
fi

#
#  Source the DLA library functions.
#

if [ "${DLAJOBSTREAMFUNC}" != "" ]
then
    if [ -r ${DLAJOBSTREAMFUNC} ]
    then
        . ${DLAJOBSTREAMFUNC}
    else
        echo "Cannot source DLA functions script: ${DLAJOBSTREAMFUNC}" | tee -a ${LOG_FILE}
        exit 1
    fi  
else
    echo "Environment variable DLAJOBSTREAMFUNC has not been defined." | tee -a ${LOG_FILE}
    exit 1
fi

#####################################
#
# Main
#
#####################################

#
# There should be a "lastrun" file in the input directory that was created
# the last time the load was run for this input file. If this file exists
# and is more recent than the input file, the load does not need to be run.
#
if [ ${QTLMODE} != "preview" ]
then
    LASTRUN_FILE=${INPUTDIR}/lastrun

    if [ -f ${LASTRUN_FILE} ]
    then
        if test ${LASTRUN_FILE} -nt ${INPUT_FILE_DEFAULT}
        then
            echo "SKIPPED: ${QTLMODE} : Input file has not been updated" | tee -a ${LOG_FILE_PROC}
	    exit 0
        fi
    fi
fi

if [ ${QTLMODE} != "preview" ]
then
    cleanDir ${LOGDIR}
    preload ${OUTPUTDIR}
    cleanDir ${OUTPUTDIR}
fi

#
# Convert the input file into a QC-ready version that can be used to run the sanity/QC reports against.
#
dos2unix ${INPUT_FILE_DEFAULT} ${INPUT_FILE_DEFAULT} 2>/dev/null

#
# run qtlarchive sanity check
#
date | tee -a ${LOG_FILE}
echo "Running qtlarchiveload : ${QTLMODE}" | tee -a ${LOG_FILE}
echo "Running QTL Archive sanity check" >> ${LOG_DIAG}
${PYTHON} ${QTLARCHIVELOAD}/bin/qtlarchiveload.py | tee -a ${LOG_DIAG}
STAT=$?
checkStatus ${STAT} "${QTLARCHIVELOAD} ${CONFIG_FILE} : ${QTLMODE} :"

#
# run association load
#
echo "Running qtlarchiveload : ${QTLMODE}" | tee -a ${LOG_FILE}
echo "Running QTL Archive association load" >> ${LOG_DIAG}
${ASSOCLOADER_SH} ${QTLARCHIVELOAD}/assocload.config ${JOBKEY}
STAT=$?
checkStatus ${STAT} "${ASSOCLOADER_SH} ${QTLARCHIVELOAD}/assocload.config"

#
# set permissions
#
case `whoami` in
    mgiadmin)
	chmod -f 775 ${FILEDIR}/*
	chgrp -f mgi ${FILEDIR}/*
	chgrp -f mgi ${FILEDIR}/*/*
	chmod -f 775 ${DESTFILEDIR}/*
	chgrp -f mgi ${DESTFILEDIR}/*
	chgrp -f mgi ${DESTFILEDIR}/*/*
	chgrp -f mgi ${QTLARCHIVELOAD}/bin
	chgrp -f mgi ${QTLARCHIVELOAD}/bin/qtlarchiveload.log
	;;
esac

#
# Archive : publshed only
# dlautils/preload with archive
#
if [ ${QTLMODE} != "preview" ]
then
    createArchive ${ARCHIVEDIR} ${LOGDIR} ${INPUTDIR} ${OUTPUTDIR} | tee -a ${LOG}
fi 

#
# Touch the "lastrun" file to note when the load was run.
#
if [ ${QTLMODE} != "preview" ]
then
    touch ${LASTRUN_FILE}
fi

#
# cat the error file
#
cat ${LOG_ERROR}
echo "" | tee -a ${LOG_FILE}
date | tee -a ${LOG_FILE}

#
# run postload cleanup and email logs
#
if [ ${QTLMODE} != "preview" ]
then
    shutDown
fi

