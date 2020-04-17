#! /bin/sh

# This script expects that you have installed your own helm3 executable. No installation of helm into kubernetes is required

export SERVER_NAME=cms-rucio-${INSTANCE}
export DAEMON_NAME=cms-ruciod-${INSTANCE}
export UI_NAME=cms-webui-${INSTANCE}
export PROBE_NAME=cms-probe-${INSTANCE}

# Ingress server. With correct labels in create_cluster.sh we should not need this anymore. Commenting out
# helm install stable/nginx-ingress --namespace kube-system --name ingress-nginx --values nginx-ingress.yaml

# Rucio server, daemons, and daemons for analysis

helm3 install $SERVER_NAME --values cms-rucio-common.yaml,cms-rucio-server.yaml,${INSTANCE}-rucio-server.yaml,${INSTANCE}-db.yaml,${INSTANCE}-release.yaml $REPO/rucio-server
helm3 install $DAEMON_NAME --values cms-rucio-common.yaml,cms-rucio-daemons.yaml,${INSTANCE}-rucio-daemons.yaml,${INSTANCE}-db.yaml,${INSTANCE}-release.yaml $REPO/rucio-daemons
helm3 install $UI_NAME --values cms-rucio-common.yaml,cms-rucio-webui.yaml,${INSTANCE}-rucio-webui.yaml,${INSTANCE}-db.yaml,${INSTANCE}-release.yaml $REPO/rucio-ui
helm3 install $PROBE_NAME --values cms-rucio-common.yaml,cms-rucio-probes.yaml,${INSTANCE}-db.yaml,${INSTANCE}-release.yaml $REPO/rucio-probes

# statsd exporter to prometheus and kube-eagle monitoring
helm3 install statsd-exporter --values statsd-prometheus-mapping.yaml,${INSTANCE}-statsd-exporter.yaml cms-kubernetes/rucio-statsd-exporter
helm3 install kube-eagle --values eagle.yaml,${INSTANCE}-eagle.yaml kube-eagle/kube-eagle

# Filebeat and logstash
#helm install --name logstash --values cms-rucio-logstash.yml,${INSTANCE}-logstash-filter.yaml stable/logstash
#helm install --name filebeat --values cms-rucio-filebeat.yml  stable/filebeat

# Create a job NOW to start setting the proxies. 
kubectl delete job --ignore-not-found=true fts
kubectl create job --from=cronjob/${DAEMON_NAME}-renew-fts-proxy fts

# Label is key to prevent it from also syncing datasets
kubectl apply -f dataset-configmap.yaml
kubectl apply -f ${INSTANCE}-sync-jobs.yaml -l syncs=rses

# Set up landb loadbalance
#numberIngressNodes=3
#n=0
#kubectl get node -o name | grep minion | while read node; do
#  [[ $((n++)) == $numberIngressNodes ]] && break
#  kubectl label --overwrite node ${node##node/} role=ingress
#done
#
#n=0
#kubectl get node -l role=ingress -o name | grep -v master | while read node; do
#  # Remove any existing aliases
#  openstack server unset --os-project-name CMSRucio --property landb-alias ${node##node/}
#  echo $((n++))
#  cnames="cms-rucio-stats-${INSTANCE}--load-${n}-,cms-rucio-${INSTANCE}--load-${n}-,cms-rucio-auth-${INSTANCE}--load-${n}-,cms-rucio-webui-${INSTANCE}--load-${n}-,cms-rucio-eagle-${INSTANCE}--load-${n}-,cms-rucio-trace-${INSTANCE}--load-${n}-"
#  openstack server set --os-project-name CMSRucio --property landb-alias=$cnames ${node##node/}
#done

./update_ingress.sh


