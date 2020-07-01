#!/bin/bash -e

PV='pv -qL'

# check if FPGA devices exist
if [ -d /sys/class/fpga ] ; then
    DRIVER=OPAE
    DEVICE_PREFIX=/dev/intel-fpga-port
elif [ -d /sys/class/fpga_region ] ; then
    DRIVER=DFL
    DEVICE_PREFIX=/dev/dfl-port
else
    >&2 echo 'ERROR: FPGA devices not found or kernel drivers not loaded'
    exit 1
fi

command()
{
  speed=$2
  [ -z "$speed" ] && speed=10

  echo "> $1" | $PV $speed
  sh -c "$1"
  echo | $PV $speed
}

out()
{
  speed=$2
  [ -z "$speed" ] && speed=10

  echo "$1" | $PV $speed
  echo | $PV $speed
}

cleanup()
{
  clear
  out 'Cleanup demo artifacts' 200
  command 'kubectl delete pod test-fpga-preprogrammed || true' 200
  command 'kubectl delete -f plugins/deployments/fpga_admissionwebhook/mappings-collection.yaml || true' 200
  command 'kubectl delete namespace intelfpgaplugin-system || true' 20
  command 'kubectl annotate node --all fpga.intel.com/device-plugin-mode-' 200
  command 'rm -rf plugins' 200
}

record()
{
  clear
  out 'Record this screencast'
  command "asciinema rec -t 'Intel FPGA Device Plugin for Kubernetes in preprogrammed mode with $DRIVER kernel driver.'  Intel-FPGA-Device-Plugin-for-Kubernetes-preprogrammed-$DRIVER-Demo.cast -c 'sh ./screencast-fpga-preprogrammed.sh play'" 300
}

screen1()
{
  clear
  out "This screencast demonstrates deployment of the Intel FPGA Plugin for Kubernetes in preprogrammed mode with $DRIVER kernel driver"
  out "Let's get started!"
  out '1. Check if Kubernetes node is in good shape:'
  command 'kubectl get nodes'
  command 'kubectl get pods -n kube-system'
  sleep 2
  out 'Check if cert-manager is running:'
  command 'kubectl get pods -n cert-manager'
  sleep 2
  out 'Check if docker is running k8s pods:'
  command 'docker ps --format "table {{.Names}}"'
  sleep 1
}

screen2()
{
  clear
  rm -rf plugins
  out '2. Clone Intel Device Plugins for Kubernetes repository'
  command "git clone https://github.com/intel/intel-device-plugins-for-kubernetes plugins" 15
  sleep 1
}

screen3()
{
  clear
  out '3. Deploy FPGA plugin'
  command 'kubectl apply -k plugins/deployments/fpga_plugin/overlays/af'
  sleep 3
  out 'Deploy example mappings:'
  command 'kubectl apply -f plugins/deployments/fpga_admissionwebhook/mappings-collection.yaml'
  sleep 3
  out 'Check if the plugin pods are running:'
  command 'kubectl get pods -n intelfpgaplugin-system'
  sleep 2
  out 'Check webhook pod logs:'
  command "kubectl logs $(kubectl get pods -n intelfpgaplugin-system| grep intelfpgaplugin-webhook | awk '{print $1}') -n intelfpgaplugin-system"
  out 'Check if the plugin runs in 'region' mode:'
  command "kubectl logs $(kubectl  get pods --namespace intelfpgaplugin-system |grep fpgadeviceplugin|cut -f1 -d' ') --namespace intelfpgaplugin-system"
  sleep 2
  out 'Check if resource fpga.intel.com/af-<af id> is allocatable:'
  command 'kubectl describe node  |grep -A4 Allocatable'
  sleep 2
}

screen4()
{
  clear
  out '4. Run OPAE workload that uses NLB3 bitstream'
  out 'Check if devices are programmed with NLB3:'
  command 'cat /sys/class/*/*/*/afu_id'
  out 'Run workload:'
  command 'cat plugins/demo/test-fpga-preprogrammed.yaml'
  command 'kubectl create -f plugins/demo/test-fpga-preprogrammed.yaml'
  sleep 5
  out 'Look at the test output'
  command 'kubectl logs test-fpga-preprogrammed'
  sleep 2
}

screen5()
{
  clear
  out 'Summary:' 15
  out "This screencast demonstrated 'Preprogrammed' use case for FPGA:" 15
  out ' - FPGA device was already programmed with NLB3 bitstream' 15
  out ' - desired bitstream resource was specified in the pod spec as fpga.intel.com/arria10.dcp1.2-nlb3-preprogrammed' 15
  out ' - the machinery mapped fpga.intel.com/arria10.dcp1.2-nlb3-preprogrammed into the pair of region id/AFU id using admission controller webhook' 15
  out
  out 'More detailed information about Intel Device Plugins can be found at https://github.com/intel/intel-device-plugins-for-kubernetes' 15
}

if [ "$1" == 'play' ] ; then
  if [ -n "$2" ] ; then
    screen$2
  else
    for n in $(seq 5) ; do screen$n ; sleep 3; done
  fi
elif [ "$1" == 'cleanup' ] ; then
  cleanup
elif [ "$1" == 'record' ] ; then
  record
else
   echo 'Usage: screencast-fpga-preprogrammed.sh [--help|help|-h] | [play [<screen number>]] | [cleanup] | [record]'
fi
