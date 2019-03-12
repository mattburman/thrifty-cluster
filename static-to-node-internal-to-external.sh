# This file attempts to maintain two properties
# that are required at all times for uptime of services
# in our cluster that lacks a cloud cloadbalancer

# 1. Node INTERNAL-IP must equal traefik service externalIP
# 2. Node EXTERNAL-IP must equal our static ip

# Dependencies: jq, kubectl authed with cluster, gcloud authed with project
# Make sure your traefik SERVICE_PATH is set, and it has an `externalIP` that can be replaced


OUR_STATIC_IP= # Put your reserved static IP here
SERVICE_PATH="services/traefik/05_service.yml"
NODE_DETAILS=`kubectl get nodes -o wide | awk '/traefik/ {print $1" "$6" "$7}'`
NODE_INSTANCE_NAME=`echo $NODE_DETAILS | cut -d' ' -f1`
NODE_INTERNALIP=`echo $NODE_DETAILS | cut -d' ' -f2`
NODE_EXTERNALIP=`echo $NODE_DETAILS | cut -d' ' -f3`

echo Node: $NODE_INSTANCE_NAME
echo Node Internal IP: $NODE_INTERNALIP
echo Node External IP: $NODE_EXTERNALIP

CURRENT_SERVICE_EXTERNALIP=`grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}" $SERVICE_PATH`
echo Current externalIP in service file: $CURRENT_SERVICE_EXTERNALIP\\n

echo 1. Node INTERNAL-IP must equal traefik service externalIP
if [ $NODE_INTERNALIP = $CURRENT_SERVICE_EXTERNALIP ];
then
	echo No replacement of externalIP in traefik service file necessary
	echo ✅ Node INTERNAL-IP already equals externalIP of traefik service: $NODE_INTERNALIP
else
	echo 👀 Replacing $CURRENT_SERVICE_EXTERNALIP with $NODE_INTERNALIP in $SERVICE_PATH
	gsed -ri "s/$CURRENT_SERVICE_EXTERNALIP/$NODE_INTERNALIP/g" $SERVICE_PATH

	echo Modified \"$SERVICE_PATH\":
	cat $SERVICE_PATH

	kubectl apply -f $SERVICE_PATH

	echo ✅ k8s traefik service externalIP now equals node INTERNAL-IP $NODE_INTERNALIP
fi
echo \\n

echo 2. Node EXTERNAL-IP must equal our static IP $OUR_STATIC_IP
if [ $NODE_EXTERNALIP = $OUR_STATIC_IP ];
then
	echo No assignment of static IP to node necessary
	echo ✅  Node EXTERNAL-IP $NODE_EXTERNALIP already $OUR_STATIC_IP
else
	echo 👀 Node EXTERNAL-IP $NODE_EXTERNALIP must be set to our static IP $OUR_STATIC_IP
	echo Replacing access config
	ACCESS_CONFIG_NAME=`gcloud compute instances describe "$NODE_INSTANCE_NAME" --format=json | jq -r '.networkInterfaces[0].accessConfigs[0].name'`

	gcloud compute instances delete-access-config "$NODE_INSTANCE_NAME" \
		--access-config-name "${ACCESS_CONFIG_NAME}"
	gcloud compute instances add-access-config "$NODE_INSTANCE_NAME" \
		--access-config-name "${ACCESS_CONFIG_NAME}" \
		--address $OUR_STATIC_IP

	NEW_ACCESS_CONFIG_NATIP=`gcloud compute instances describe "$NODE_INSTANCE_NAME" --format=json | jq -r '.networkInterfaces[0].accessConfigs[0].natIP'`

	if [ $NEW_ACCESS_CONFIG_NATIP = $OUR_STATIC_IP ];
	then
		echo ✅  Node EXTERNAL-IP $NODE_EXTERNALIP now $OUR_STATIC_IP
	else
		echo ⚠️  Unable to assign our static IP to node.
		echo See https://console.cloud.google.com/networking/addresses/list?project=mattburman
	fi
fi

