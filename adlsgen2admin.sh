#!/bin/bash
# Utility: Simple BASH based ADLS Gen2 Filesystem Aministration Utility
# Version: 1.0.0

# Usage function
usage() {
  echo "Usage: adlsgen2admin.sh -a FILESYSTEM_ACTION -f FILESYSTEM_RESOURCEPATH [-l LOCAL_FILE] [-p PROXY_SERVER]
 
       FILESYSTEM_ACTION       -> Filesystem action to perform, supported LS, MKDIR, CAT, PUT, RM, RMDIR
       FILESYSTEM_RESOURCEPATH -> ADLS Resource detail, FORMAT: STORAGE_ACCOUNT/FILESYSTEM@PATH_IN_ADLS
       LOCAL_FILE (Optional)   -> Applicable only for PUT action, path of your local file to be PUT in ADLS
       PROXY_SERVER (Optional) -> Your proxy server if applicable, eg: http://127.0.0.1:3128

NOTE: The tool uses SPN(OAuth) to authenticate, thus you need to export CLIENT_ID, CLIENT_SECRET and TENENT_ID in environment."
  exit 1
}

supported_action="ls,mkdir,put,cat,rmdir,rm"
is_proxy=""
action=""
fs_uri=""
local_file=""
CURL="curl"

while [ $# -gt 0 ]
do
  key=$1
  case $key in
  -p) is_proxy="$2"
      shift
      shift
      ;;
  -l) local_file="$2"
      shift
      shift
      ;;
  -a) action="$(echo $2 | tr [A-Z] [a-z])"
      shift
      shift
      ;;
  -f) fs_url="$2"
      shift
      shift
      ;;
done

if [ -z "${CLIENT_ID}" -o -z "${CLIENT_SECRET}" -o -z "${TENENT_ID}" ]
then
  echo "ERROR: Environment not set"
  usage
fi

if [ ! -z "$is_proxy" ]
then
  CURL="curl -x ${is_proxy} "
fi

if [ $(echo ${supported_action} | tr "," "\n" | grep -q ${action}; echo $?) -ne 0 ]
then
  echo "ERROR: Action ${action} not supported"
  usage
fi

storage_account=$(echo ${fs_url} | awk -F'@' '{ print $1 }' | awk -F'/' '{ print $1 }')
storage_fs=$(echo ${fs_url} | awk -F'@' '{ print $1 }' | awk -F'/' '{ print $2 }')
storage_path=$(echo ${fs_url} | awk -F'@' '{ print $2 }')

if [ -z "${storage_account}" -o -z "${storage_fs}" -o -z "${storage_path}" ]
then
  echo "ERROR: Resource URL ${fs_url} is invalid"
  usage
fi

access_token=$(${CURL} -ks -H "Content-Type: application/x-www-form-urlencoded" --data "grant-type=client_credentials&scope=https://storage.azure.com/.default&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}" https://login.microsoftonline.com/${TENENT_ID}/oauth2/v2.0/token | python -c "import sys, json; data=json.load(sys.stdin); print data['access_token']")

if [ "$(echo $action | tr [A-Z] [a-z])" == "ls" ]
then
  ${CURL} -ks -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer ${access_token}" "https://${storage_account}.dfs.core.windows.net/${storage_fs}?resource=filesystem&directory=${storage_path}&recursive=false" | python -c "import sys, json; data=json.load(sys.stdin); fs_list=data['paths']; print '\n'.join([r['name'] for r in fs_list])"

elif [ "$(echo $action | tr [A-Z] [a-z])" == "mkdir" ]
then
  ${CURL} -ks -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer ${access_token}" -H "content-length: 0" -X PUT "https://${storage_account}.dfs.core.windows.net/${storage_fs}${storage_path}?resource=directory"

elif [ "$(echo $action | tr [A-Z] [a-z])" == "rmdir" ]
then
  ${CURL} -ks -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer ${access_token}" -X DELETE "https://${storage_account}.dfs.core.windows.net/${storage_fs}${storage_path}?recursive=true"

elif [ "$(echo $action | tr [A-Z] [a-z])" == "rm" ]
then
  ${CURL} -ks -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer ${access_token}" -X DELETE "https://${storage_account}.dfs.core.windows.net/${storage_fs}${storage_path}"

elif [ "$(echo $action | tr [A-Z] [a-z])" == "cat" ]
then
  ${CURL} -ks -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer ${access_token}" -X GET "https://${storage_account}.dfs.core.windows.net/${storage_fs}${storage_path}"

elif [ "$(echo $action | tr [A-Z] [a-z])" == "put" ]
then
  if [ -z "${local_file}" -o ! -f "${local_file}" ]
  then
    echo "ERROR: ${local_file} is not a valid file"
    usage
  fi
  file_data=$(cat ${local_file})
  ${CURL} -ks -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer ${access_token}" -H "content-length: 0" -X PUT "https://${storage_account}.dfs.core.windows.net/${storage_fs}${storage_path}?resource=file"
  [ $? -ne 0 ] && exit 1
  ${CURL} -ks -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer ${access_token}" -H "content-type: text/plain" -H "content-length: ${#file_data}" --data "${file_data}" -X PATCH "https://${storage_account}.dfs.core.windows.net/${storage_fs}${storage_path}?action=append&position=0"
  [ $? -ne 0 ] && exit 1
  ${CURL} -ks -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer ${access_token}" -H "content-type: text/plain" -H "content-length: 0" -X PATCH "https://${storage_account}.dfs.core.windows.net/${storage_fs}${storage_path}?action=flush&close=true&position=${#file_data}"

fi
