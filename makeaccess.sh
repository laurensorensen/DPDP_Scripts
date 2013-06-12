#!/bin/bash
# make access
version=0.2
#requires uuid (ossp-uuid), ffmpeg, xmlstarlet
#Associated scripts: verifySIPCompliance.py 
script_dir=`dirname "$0"`
package_path="$1"

onjects_path="./objects"
logs_path="./metadata/submissionDocumentation/logs"
techmd_path="./metadata/submissionDocumentation/techmd"
access_path="./objects/access"

metadata_path="./metadata"
ffmpeg_exe="/usr/local/bin/ffmpeg"

#checks on script arguments, package compliance check, will it conform and run in Archivematica?
[ "$#" -ne "1" ] && { echo This script requires one argument, the path to a repository SIP. ; exit 1 ;};
[ ! -d "$package_path" ] && { echo "$package_path" is not a directory. ; exit 1 ;};

# warning, deleting .DS_Store files before processing package
find "$PACKAGE" -name '*.DS_Store' -type f -delete

verifySIPCompliance.py "$package_path"
[ "$?" != 0 ] && { echo "$package_path file SIP Compliance tests." ; exit 1 ;};

# Add media tests here. At this point this requires an object of one media file.

startdir=`pwd`
cd "$package_path"
mkdir -p "$access_path"
for file in `find ./objects -maxdepth 1 -mindepth 1 ! -name '.*' -type f` ; do

    base=`basename "$file"`

    #check pre-requisites
    if [ -s "${access_path}/${base%.*}.mp4" ] ; then
        echo "${access_path}/${base%.*}.mp4 already exists"
        # use output code to indicate that the service is not needed
        exit 86
    fi

    #set premis event variables
    eventIdentifierType="UUID"
    eventIdentifierValue=`uuid -v 4`
    eventType="compression-mp4.h264.bv750.aac.ba128-v1"
    eventDateTime=`date "+%FT%T"`
    eventDetail="Original object is compressed for access compliant with web-streaming"
    sourceLinkingObjectIdentifierType="URI"
    sourceLinkingObjectIdentifierValue="$file"
    outcomeLinkingObjectIdentifierType="UUID"
    outcomeLinkingObjectIdentifierValue=`uuid -v 4`
    linkingAgentRole="Executing program"
    
    #set premis agent variables
    agentIdentifierType="URI"
    agentIdentifierValue="http://ffmpeg.org"
    agentName="FFmpeg"
    agentType="software"
    agentNote=`"$ffmpeg_exe" -version 2> /dev/null`
    linkingEventIdentifierType="$eventIdentifierType"
    linkingEventIdentifierValue="eventIdentifierValue"
    
    #ffmpeg time
    event_logs_path="$logs_path/$eventType"
    mkdir -p "$event_logs_path"
    mkdir -p "$techmd_path"
    export FFREPORT="file=${event_logs_path}/%p_%t_$(basename $0)_${version}.txt"
    "$ffmpeg_exe" -n -report -i "$file" -c:v libx264 -pix_fmt yuv420p -b:v 750k -vf "yadif" -c:a:1 aac -b:a 128k "${access_path}/${base%.*}.mp4"
    EC=`echo "$?"`
    if [ "$EC" -ne "0" ] ; then
        eventOutcome="failure"
        #quarantine?
    else
        eventOutcome="success"
    fi
    cd "$startdir"
    [ ! -f "$package_path/metadata/premis.xml" ] && start_premis.sh "$package_path"
    premis_add_event.sh -x "$package_path/metadata/premis.xml" -i "$eventIdentifierType" -I "$eventIdentifierValue" -T "$eventType" -d "$eventDateTime" -D "$eventDetail" -E "$eventOutcome" -l "$agentIdentifierType" -L "$agentIdentifierValue" -r "$linkingAgentRole" -s "$sourceLinkingObjectIdentifierType" -S "$sourceLinkingObjectIdentifierValue" -o "URI" -O "./objects/access/${base%.*}.mp4"
    premis_add_agent.sh -x "$package_path/metadata/premis.xml" -i "$agentIdentifierType" -I "$agentIdentifierValue" -n "$agentName" -T "$agentType" -N "$agentNote" -l "$eventIdentifierType" -L "$eventIdentifierValue"

done

smnadmin@smn:~$ 
