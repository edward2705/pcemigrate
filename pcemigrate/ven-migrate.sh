#!/bin/bash
#
# Script    : ven-migrate.sh
# Comments  : script to unpair and repair the VEN
# Dependency: requires workloads.csv generated from workloader or pcemigrate.sh script
#           : requires agent.conf to configure agent parameters
# Version   : 1.1
# Date      : 12-2023
# 
#

BDIR=$(dirname $0)
WKLD_FILE="${BDIR}/workloads.csv"
AGENT_CONFIG="${BDIR}/ven-migrate.conf"
LOGFILE="$BDIR/$(basename $0).log"
USE_CONFIGFILE=""
migrate_type=""
VENDIR=""
port=""
APP_PARAM=""
ENV_PARAM=""
LOC_PARAM=""
ROLE_PARAM=""
ENFORCEMENT_MODE=""
DEBUG=1


usage() {
  echo -e "\nUsage: $0 --use_configfile --pce pce [ --port port ] --activation_code activation_code --migrate_type [ activate | pair] [ --api_version API_VERSION ] [ --profile_id profile_id ] [ --vendir VEN directory ]"
  echo -e "Where: "
  echo -e "  --use_configfile"
  echo -e "    Use ven-migrate.conf configuration file"
  echo -e "  --pce pce"
  echo -e "  --port port, default: 443 [optional]"
  echo -e "  --activation_code activation code"
  echo -e "  --migrate_type activate | pair"
  echo -e "    activate = deactivate and activate the ven"
  echo -e "    pair = unpair and pair the ven"
  echo -e "  --api_version API_VERSION, default: v25"
  echo -e "  --profile_id profile_id"
  echo -e "  --vendir VEN directory, default: /opt/illumio_ven"
  echo
  exit 1
}

debug_print() {
  if [ $DEBUG ]; then
    LOG_DTE=$(date '+%Y-%m-%d %H:%M:%S' | tr -d '\n')
    echo "$LOG_DTE $1 $2" 
    echo "$LOG_DTE $1 $2" >> $LOGFILE
  fi
}

get_workload_label() {
   WKLD_LABEL=$(cat $WKLD_FILE | uniq | grep ^$WKLD_HOST)
   APP=$(echo $WKLD_LABEL | cut -d, -f2)
   ENVM=$(echo $WKLD_LABEL | cut -d, -f3)
   LOC=$(echo $WKLD_LABEL | cut -d, -f4)
   ROLE=$(echo $WKLD_LABEL | cut -d, -f5)
   ENFORCEMENT_MODE=$(echo $WKLD_LABEL | cut -d, -f6)
   [[ -n $APP ]] && APP_PARAM="--app \"$APP\""
   [[ -n $ENVM ]] && ENV_PARAM="--env \"$ENVM\""
   [[ -n $LOC ]] && LOC_PARAM="--loc \"$LOC\""
   [[ -n $ROLE ]] && ROLE_PARAM="--role \"$ROLE\""
}


unpair_cmd() {
  debug_print "executing ven unpair command" 
  debug_print "/opt/illumio_ven/illumio-ven-ctl unpair open"
  /opt/illumio_ven/illumio-ven-ctl unpair open 


}

pair_cmd() {
 debug_print "executing ven pairing command"
 debug_print "rm -fr /opt/illumio_ven_data/tmp && umask 026 && mkdir -p /opt/illumio_ven_data/tmp && curl --tlsv1 \"https://$pce:$port/api/$API_VERSION/software/ven/image?pair_script=pair.sh&profile_id=$profile_id\" -o /opt/illumio_ven_data/tmp/pair.sh && chmod +x /opt/illumio_ven_data/tmp/pair.sh && /opt/illumio_ven_data/tmp/pair.sh --management-server $pce:$port --activation-code $activation_code --enforcement_mode \"$ENFORCEMENT_MODE\" $ROLE_PARAM $APP_PARAM $ENV_PARAM $LOC_PARAM"
 
 rm -fr /opt/illumio_ven_data/tmp && umask 026 && mkdir -p /opt/illumio_ven_data/tmp && curl --tlsv1 "https://$pce:$port/api/$API_VERSION/software/ven/image?pair_script=pair.sh&profile_id=$profile_id" -o /opt/illumio_ven_data/tmp/pair.sh && chmod +x /opt/illumio_ven_data/tmp/pair.sh && /opt/illumio_ven_data/tmp/pair.sh --management-server $pce:$port --activation-code $activation_code --enforcement_mode "$ENFORCEMENT_MODE" $ROLE_PARAM $APP_PARAM $ENV_PARAM $LOC_PARAM
}

ven_activate() {
  debug_print "workload: $WKLD_HOST; role: $ROLE; app: $APP; env: $ENVM; loc: $LOC"
  debug_print "$VENDIR/illumio-ven-ctl activate --management-server $pce:$port --activation-code $activation_code --enforcement_mode $ENFORCEMENT_MODE $ROLE_PARAM $APP_PARAM $ENV_PARAM $LOC_PARAM"
  $VENDIR/illumio-ven-ctl activate --management-server $pce:$port --activation-code $activation_code --enforcement_mode $ENFORCEMENT_MODE $ROLE_PARAM $APP_PARAM $ENV_PARAM $LOC_PARAM
  debug_print "sleeping for 10 secs before checking the ven status"
  sleep 10
  debug_print
  $VENDIR/illumio-ven-ctl status
  echo
}

ven_deactivate() {
  debug_print "deactivating the ven"
  debug_print "executing $VENDIR/illumio-ven-ctl deactivate"
  $VENDIR/illumio-ven-ctl deactivate
  $VENDIR/illumio-ven-ctl status
}



### Main Program ###

WKLD_HOST=$(hostname | tr -d '\n')

VALID_ARGS=$(getopt -o :: --long ,use_configfile,pce:,port:,activation_code:,migrate_type:,api_version:,profile_id:,vendir: -- "$@")
RC=$?

if [ "$RC" != "0" ]; then
  exit 1
fi

eval set -- "$VALID_ARGS"

while [ : ]; do
  case "$1" in
    --use_configfile)
        USE_CONFIGFILE=1; shift ;;
    --pce)
        pce="$2"; shift 2 ;;
    --port)
        port="$2"; shift 2 ;;
    --activation_code)
        activation_code="$2"; shift 2 ;;
    --migrate_type)
        migrate_type="$2"; shift 2 ;;
    --api_version)
        API_VERSION="$2"; shift 2 ;;
    --profile_id)
        profile_id="$2"; shift 2 ;;
    --vendir)
        VENDIR="$2"; shift 2 ;;
    --) shift; break ;;
  esac
done

[[ -z $VENDIR ]] && VENDIR="/opt/illumio_ven"
[[ -z $port ]] && port="443"
[[ -z $AGENT_ID ]] && API_VERSION="v25"

if [ -z $USE_CONFIGFILE ]; then
  [[ -z $activation_code ]] && [[ -z $pce ]] && usage
else 
  if [ -r $AGENT_CONFIG ]; then
    debug_print "$AGENT_CONFIG file found!"
. $AGENT_CONFIG
  else
    debug_print "ERROR: $AGENT_CONFIG file does not exist!"
    exit 1
  fi 
fi

debug_print "pce: $pce, port: $port, activation_code: $activation_code"
debug_print "migrate_type: $migrate_type, api_version: $API_VERSION, profile_id: $profile_id"

get_workload_label

if [ $migrate_type = "activate" ]; then
  ven_deactivate
  sleep 3
  ven_activate
elif  [ $migrate_type = "pair" ]; then
  unpair_cmd
  pair_cmd
fi

exit 0


