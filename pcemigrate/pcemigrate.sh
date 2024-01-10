#!/bin/bash
#
#
# Copyright (c) 2020 by Illumio. All rights reserved.
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
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright (c) 2022 by Illumio. All rights reserved.
#
# Author  : Edward de los Santos
# Script  : pcemigrate.sh
# Comments: Script to migrate PCE Objects 
#           Supported versions: 19.3.6,20.x,21.x,22.x
# Dependency: Script requires workloader to work
# Version : 1.6
# Date    : 01-2024


BASEDIR=$(dirname $0)
PROG=$(basename $0)
DTE=$(date '+%Y%m%d.%H%M%S' | tr -d '\n')
HOSTNAME=$(hostname)
LOGFILE=""
WORKLOADER="$BASEDIR/workloader"
DATADIR="$BASEDIR/exported_data"
PCE=""

log_print() {
  LOG_DTE=$(date '+%Y-%m-%d %H:%M:%S' | tr -d '\n')
  echo "$1"
  echo "$LOG_DTE $1 $2" >> $LOGFILE
}

export_objects() {
  PCE=$1
  WORKLOADER_CMDS="label-dimension-export label-export svc-export ipl-export labelgroup-export wkld-export ruleset-export rule-export eb-export"
  for WCMD in $(echo $WORKLOADER_CMDS); do
    OUTFILE="$DATADIR/$PCE.$WCMD.csv"
    BACKUPFILE="$DATADIR/backup/$PCE.$WCMD.$DTE.csv"
    MANAGED_WKLD_FILE="$DATADIR/$PCE.$WCMD.managed.csv"
    cat /dev/null > $OUTFILE
    cat /dev/null > $BACKUPFILE

    echo 
    echo ". executing $WORKLOADER $WCMD --output-file $OUTFILE"
    $WORKLOADER $WCMD --output-file $OUTFILE --no-href
    $WORKLOADER $WCMD --output-file $BACKUPFILE

    [ "$WCMD" = "ruleset-export" ] &&  cat $OUTFILE > $OUTFILE.import
    #[ "$WCMD" = "rule-export" ] &&  cat $OUTFILE | cut -f1-32 -d, > $OUTFILE.import
    [ "$WCMD" = "rule-export" ] &&  cat $OUTFILE > $OUTFILE.import
    [ "$WCMD" = "eb-export" ] &&  cat $OUTFILE  > $OUTFILE.import
    [ "$WCMD" = "svc-export" ] &&  cat $OUTFILE | grep -v "All Services" > $OUTFILE.import
    [ "$WCMD" = "labelgroup-export" ] &&  cat $OUTFILE > $OUTFILE.import
    [ "$WCMD" = "label-export" ] &&  cat $OUTFILE  > $OUTFILE.import
    [ "$WCMD" = "wkld-export" ] &&  cat $OUTFILE  > $OUTFILE.import
    [ "$WCMD" = "label-dimension-export" ] &&  cat $OUTFILE  > $OUTFILE.import
    [ "$WCMD" = "ipl-export" ] &&  cat $OUTFILE | grep -v "^Any "  > $OUTFILE.import
    
  done

  # Replace wkld-export output where hostname null values with the name value
  WCMD="wkld-export"
  OUTFILE="$DATADIR/$PCE.$WCMD.csv"
  awk -F "," -v OFS="," '{ if ($1 == "") { $1=$2 }; {print $0} }' $OUTFILE > $OUTFILE.import

  # export managed workload only
  OUTFILE="$DATADIR/$PCE.$WCMD-managed.csv"
  WKLD_LABEL_ONLY="./workloads.csv"
  echo
  echo ". executing $WORKLOADER $WCMD --managed-only --output-file $OUTFILE"
  $WORKLOADER $WCMD --managed-only --output-file $OUTFILE --no-href
  OUTFILE_TMP=$OUTFILE
  awk -F "," -v OFS="," '{ if ($1 == "") { $1=$2 }; {print $0}}' $OUTFILE_TMP > $OUTFILE.import
  $WORKLOADER $WCMD --managed-only --output-file $BACKUPFILE
  echo
  echo ". generating $WKLD_LABEL_ONLY file"
  cat $OUTFILE | cut -d, -f1,3,4,5,6,15 > $WKLD_LABEL_ONLY

}

gen_workloads() {
PCE=$1

  WCMD="wkld-export"
  # export managed workload only
  OUTFILE="$DATADIR/$PCE.$WCMD-managed.csv"
  BACKUPFILE="$DATADIR/backup/$PCE.$WCMD.$DTE.csv"
  WKLD_LABEL_ONLY="./workloads.csv"
  echo
  echo ". executing $WORKLOADER $WCMD --managed-only --output-file $OUTFILE"
  $WORKLOADER $WCMD --managed-only --output-file $OUTFILE --no-href
  OUTFILE_TMP=$OUTFILE
  awk -F "," -v OFS="," '{ if ($1 == "") { $1=$2 }; {print $0}}' $OUTFILE_TMP > $OUTFILE.import
  $WORKLOADER $WCMD --managed-only --output-file $BACKUPFILE
  echo
  echo ". generating $WKLD_LABEL_ONLY file"
  cat $OUTFILE | cut -d, -f1,3,4,5,6,15 > $WKLD_LABEL_ONLY
}


import_objects() {
  PCE=$1
  WORKLOADER_CMDS="label-dimension-import label-import svc-import ipl-import labelgroup-import wkld-import ruleset-import rule-import eb-import"
  for WCMD in $(echo $WORKLOADER_CMDS); do
    WCMD_EXPORT=$(echo $WCMD | sed 's/import/export/g')
    OUTFILE="$DATADIR/$PCE.$WCMD_EXPORT.csv.import"
    echo 
    if [ "$WCMD" = "svc-import" ] || [ "$WCMD" = "label-dimension-import" ] || [ "$WCMD" = "label-import" ] || [ "$WCMD" = "ipl-import" ] || [ "$WCMD" = "labelgroup-import" ] || [ "$WCMD" = "eb-import" ] ; then
      echo ". executing $WORKLOADER $WCMD $OUTFILE --update-pce --no-prompt"
      $WORKLOADER $WCMD $OUTFILE --update-pce --no-prompt
    fi

    if [ "$WCMD" = "wkld-import" ]; then
      echo ". executing $WORKLOADER $WCMD $OUTFILE --umwl --update-pce --no-prompt"
      $WORKLOADER $WCMD $OUTFILE --umwl --update-pce --no-prompt
    fi

    if [ "$WCMD" = "ruleset-import" ] || [ "$WCMD" = "rule-import" ]; then
      echo ". executing $WORKLOADER $WCMD $OUTFILE --update-pce --no-prompt"
      $WORKLOADER $WCMD $OUTFILE --update-pce --no-prompt
    fi
  done

}

create_umwl() {
  PCE=$1
  WKLD_HOST=$2
  WCMD="wkld-export"
  MANAGED_FILE="$DATADIR/$PCE.wkld-export-managed.csv"
  OUTFILE="$DATADIR/$PCE.$WCMD-unmanaged.csv"

  echo
  echo ". executing $WORKLOADER $WCMD --managed-only --output-file $MANAGED_FILE"
  $WORKLOADER $WCMD --managed-only --output-file $MANAGED_FILE
  
  echo ". creating unmanaged workloads $OUTFILE"

  # create unmanaged workloads header
  echo "hostname,name,app,env,loc,role,interfaces,default_gw" > $OUTFILE
  # skip header,write unmanaged workload file
  awk -F "," -v OFS="," 'FNR>1 { if ($1 == "") {print $2"-umw",$2"-umw",$11,$12,$13,$14,$3,$8} else if ($2 == "") {print $1"-umw",$1"-umw",$11,$12,$13,$14,$3,$8} else {print $1"-umw",$2"-umw",$11,$12,$13,$14,$3,$8} }' $MANAGED_FILE >> $OUTFILE
  #awk -F "," -v OFS="," '{ if ($1 == "") { $1=$2"-umw"; $2=$2"-umw" } else if ($2 == "") { $1=$1"-umw"; $2=$1 } else { $1=$1"-umw"; $2=$2"-umw" }; {print $0}}' $MANAGED_FILE >> $OUTFILE

  if [ "$WKLD_HOST" != "" ]; then
    cp $OUTFILE $OUTFILE.tmp
    WKLD_OUTFILE=$OUTFILE.tmp
    cat $WKLD_OUTFILE | egrep "^hostname|\b$WKLD_HOST\b" > $OUTFILE
    cat $OUTFILE
  fi

  WCMD="wkld-import"
  echo ". executing on $PCE: $WORKLOADER $WCMD --umwl --update-pce --no-prompt $OUTFILE"
  $WORKLOADER $WCMD --umwl --update-pce --no-prompt $OUTFILE --debug
}

delete_umwl() {
  PCE=$1
  WKLD_HOST=$2
  #WORKLOADER="$BASEDIR/workloader.910"
  WORKLOADER="$BASEDIR/workloader"

  # export managed workload only
  WCMD="wkld-export"
  OUTFILE="$DATADIR/$PCE.$WCMD-managed.csv"
  BACKUPFILE="$DATADIR/backup/$PCE.$WCMD.$DTE.csv"
  echo
  echo ". executing on $PCE: $WORKLOADER $WCMD --managed-only --output-file $OUTFILE"
  $WORKLOADER $WCMD --managed-only --output-file $OUTFILE
  $WORKLOADER $WCMD --managed-only --output-file $BACKUPFILE


  WCMD="umwl-cleanup"
  OUTFILE="$DATADIR/$PCE.$WCMD.csv"
  echo
  echo ". executing on $PCE: $WORKLOADER $WCMD --output-file $OUTFILE"
  $WORKLOADER $WCMD --output-file $OUTFILE

  if [ "$WKLD_HOST" != "" ]; then
    cp $OUTFILE $OUTFILE.tmp
    WKLD_OUTFILE=$OUTFILE.tmp
    cat $WKLD_OUTFILE | egrep "^managed_hostname|\b$WKLD_HOST\b" > $OUTFILE
    cat $OUTFILE
  fi


  WCMD="delete"
  echo  
  echo ". executing on $PCE: $WORKLOADER $WCMD --header umwl_href --update-pce --no-prompt $OUTFILE"
  #$WORKLOADER $WCMD --header umwl_href --update-pce --no-prompt $OUTFILE
  $WORKLOADER $WCMD --header unmanaged_href --update-pce --no-prompt $OUTFILE
}

is_active_pce() {
PCE=$1
  # return 1 if active
  return $($WORKLOADER pce-list | grep $PCE | grep -c "*")
}

set_active_pce() {
PCE=$1
  # set default pce
  echo ". setting active pce to $PCE"
  $WORKLOADER settings --default-pce $PCE
}

get_pcelist() {
  echo
  echo ". executing $WORKLOADER pce-list"
  $WORKLOADER pce-list
}


usage() {
   echo
   echo "Usage: $0 -e|--export -i|--import -c|--create-umwl -d|--delete-umwl --from-pce <pce_name> --to-pce <pce_name>"
   echo "  -e|--export             Export Illumio Objects (labels, labelgroups, service, rules, rulesets, workloads)"
   echo "  -i|--import             Export Illumio Objects (labels, labelgroups, service, rules, rulesets, workloads)"
   echo "  -c|--create-umwl        Create unmanaged workloads on existing managed workloads"
   echo "  -d|--delete-umwl        Delete unmanaged workloads on existing managed workloads"
   echo "  -s|--commit             Commit umwl changes [functionality to be added]"
   echo "  -w|--workload           Workload"
   echo "  -g|--gen-workloads      Generate workloads.csv"
   echo "  -f|--from-pce pce_name  Source PCE"
   echo "  -t|--to-pce pce_name    Target PCE"
   echo

   exit 1
}


# Main Program
EXPORT_OBJ=0
IMPORT_OBJ=0
DELETE_UMWL=0
CREATE_UMWL=0
FROM_PCE=""
TO_PCE=""


PARSED_ARGUMENTS=$(getopt -a -n pcemigrate -o eigcdsf:t: --long export,import,create-umwl,delete-umwl,commit,gen-workloads,workload:,from-pce:,to-pce: -- "$@")
VALID_ARGUMENTS=$?

if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"


while :
do
  case "$1" in
    -e | --export)        EXPORT_OBJ=1   ; shift   ;;
    -i | --import)        IMPORT_OBJ=1   ; shift   ;;
    -c | --create-umwl)   CREATE_UMWL=1  ; shift   ;;
    -d | --delete-umwl)   DELETE_UMWL=1  ; shift   ;;
    -s | --commit)        COMMIT=1       ; shift   ;;
    -g | --gen-workloads) GEN_WKLDS=1    ; shift   ;;
    -w | --workload)      WKLD_HOST="$2" ; shift 2 ;;
    -f | --from-pce)      FROM_PCE="$2"  ; shift 2 ;;
    -t | --to-pce)        TO_PCE="$2"    ; shift 2 ;;
    --) shift; break ;;
    *) usage ;;
  esac
done

[ ! -d "$BASEDIR/exported_data/backup" ] && mkdir -p $BASEDIR/exported_data/backup

if [ "$FROM_PCE" = "" ] &&  [ "$TO_PCE" = "" ]; then
  usage
fi

if [ $EXPORT_OBJ -eq 1 ] && [ $IMPORT_OBJ -eq 1 ] ; then
  usage
elif [ "$FROM_PCE" != "" ] && [ $GEN_WKLDS -eq 1 ]; then
  set_active_pce "$FROM_PCE"
  gen_workloads "$FROM_PCE"
elif [ $EXPORT_OBJ -eq 1 ] && [ "$FROM_PCE" != "" ]; then
  clear
  set_active_pce "$FROM_PCE"
  export_objects "$FROM_PCE"
  echo 
  echo ". creating tar file $BASEDIR/$FROM_PCE.exported_data.$DTE.tar for exported_data"
  tar cfz $BASEDIR/$FROM_PCE.exported_data.$DTE.tar $BASEDIR/exported_data
  echo
  echo "<<<< END >>>>"
elif [ $IMPORT_OBJ -eq 1 ] && [ $FROM_PCE != "" ] && [ $TO_PCE != "" ]; then
  clear
  set_active_pce "$TO_PCE"
  is_active_pce "$TO_PCE"
  if [ $? -eq 1 ]; then
     echo ". source pce: $FROM_PCE"
     echo ". target pce: $TO_PCE is ACTIVE"
     echo 
     echo ". <<< Please make sure the SOURCE and TARGET PCE is correct >>>"
     echo
     read -p ". Proceed with Migration? (Y/N): " CONFIRM && [[ $CONFIRM == [yY] || $CONFIRM == [yY][eE][sS] ]] || exit 1
     import_objects $FROM_PCE
  fi 
elif [ $CREATE_UMWL -eq 1 ] && [ $FROM_PCE != "" ]; then
  set_active_pce "$FROM_PCE"
  create_umwl "$FROM_PCE" "$WKLD_HOST"

elif [ $DELETE_UMWL -eq 1 ] && [ $FROM_PCE != "" ];  then
  set_active_pce "$FROM_PCE"
  delete_umwl "$FROM_PCE" "$WKLD_HOST"
fi


  





