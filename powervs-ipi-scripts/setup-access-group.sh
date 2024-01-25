#!/bin/sh
#

abort() {
  echo "ERROR: $1 -- aborting..."
  exit 1
}

# expects $ROLES to have the list of roles for the target service
addPolicy() {
  TMPF=$(mktemp)
  $IAM access-group-policy-create $ACCESSGRP -q --roles "$ROLES" $* > $TMPF 2>&1
  if [ $? -ne 0 ]; then
    test "$DEBUG" && cat $TMPF || grep 'Error response' $TMPF | grep -v 'identical attributes already exist'
  fi
  rm -f $TMPF
}

# parse options specified
while :; do
  case $1 in
    -a)
      test "$2" && { ACCESSGRP=$2; shift; } || abort "no Access Group name specified for $1"
      ;;
    -d)
      DEBUG=true
      ;;
    -h)
      echo "$0 [-a access-group-name] [-r resource-group-name] [-u ibmid-user] [-d] [-h]"
      echo "  -a: specifies the access group to populate with necessary policies, or uses the default name"
      echo "  -r: specifies the resource group to tie the policies to, or defaults to the Default group"
      echo "  -u: optionally adds the IBMid user to the access group"
      exit 0
      ;;
    -r)
      test "$2" && { RESOURCEGRP=$2; shift; } || abort "no Resource Group name specified for $1"
      ;;
    -u)
      test "$2" && { IBMID=$2; shift; } || abort "no IBMid username specified for $1"
      ;;
    *)
      break
  esac
  shift
done

ICCMD=ibmcloud
IAM="$ICCMD iam"
test -n "$ACCESSGRP"   || ACCESSGRP=powervs-ipi-access-group
test -n "$RESOURCEGRP" || RESOURCEGRP=powervs-ipi-resource-group
DEFAULT_RG=$($ICCMD resource groups -q --default | grep ^Name | awk '{print $2}')

# create the access group as needed
#
$IAM access-groups | grep -q "^$ACCESSGRP\s"
test $? -eq 0 || $IAM access-group-create $ACCESSGRP

# necessary permissions for "create cluster"
#
ROLES="Viewer"
addPolicy --resource-group-name $RESOURCEGRP

ROLES="Viewer,Reader"
addPolicy --service-name internet-svcs --resource-group-name $RESOURCEGRP

ROLES="Viewer,Operator,Editor,Reader,Writer,Manager,Content Reader,Object Reader,Object Writer"
addPolicy --service-name cloud-object-storage

ROLES="Viewer,Operator,Editor,Reader,Manager"
addPolicy --service-name power-iaas --resource-group-name $RESOURCEGRP

ROLES="Viewer,Operator,Editor,Administrator,Reader,Writer,Manager"
addPolicy --service-name internet-svcs --resource-group-name $RESOURCEGRP

ROLES="Viewer,Operator,Editor"
addPolicy --service-name directlink

ROLES="Viewer,Operator,Editor,Administrator,Reader,Writer,Manager,Console Administrator"
addPolicy --service-name is --resource-group-name $RESOURCEGRP

ROLES="Viewer,Operator,Editor,Administrator,Manager"
addPolicy --service-name transit --resource-group-name $RESOURCEGRP

ROLES="Viewer,Operator,Editor,Reader,Writer,Manager"
addPolicy --service-name internet-svcs --attributes "cfgType=reliability"  --resource-group-name $RESOURCEGRP

test "$DEBUG" && $IAM access-group-policies $ACCESSGRP -q # --output json

test -n "$IBMID" && $IAM access-group-user-add -q $ACCESSGRP $IBMID