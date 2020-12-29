#!/bin/bash

function check_deps() {
  test -f $(which jq) || { echo "jq command not detected in path, please install it" && exit 1; }
}

function parse_input() {
  eval "$(jq -r '@sh "export resource_type=\(.resource_type) resource_name=\(.resource_name) namespace=\(.namespace) query_type=\(.query_type)"')"
  if [[ -z "${resource_type}" ]]; then echo "resource_type is empty" && exit 1; fi
  if [[ -z "${resource_name}" ]]; then echo "resource_name is empty" && exit 1; fi
  if [[ -z "${namespace}" ]]; then echo "resource_name is empty" && exit 1; fi
}

function return_data() {
#  if [[ ${query_type} == "uid" ]]
#  then
#      export spec_path=".metadata.uid"
#  fi
   case ${query_type} in

     uid)
       export spec_path=".metadata.uid"
       ;;

     nodeport)
       export spec_path=".spec.ports[*].nodePort"
       ;;
     *)
       echo -n "query_type ${query_type} is unknown" && exit 1
       ;;
   esac
  VAL=$(kubectl get ${resource_type} ${resource_name} -n ${namespace} -o jsonpath='{'${spec_path}'}')
  NAME=$(kubectl get ${resource_type} ${resource_name} -n ${namespace} -o jsonpath='{.metadata.name}')
  #echo $VAL
  nodeport_count=$(echo ${VAL} | wc -w)
  if [[ "${nodeport_count}" -gt 1 ]]
  then
      VAL=$(echo ${VAL} | awk '{gsub(/[ ]+/, ","); print "["$0"]"}')
  fi
  jq -n \
    --arg ${query_type} "$VAL" \
    --arg name "$NAME" \
    '{"'${query_type}'":$'${query_type}', "name":$name}'
}

check_deps && \
parse_input && \
return_data
