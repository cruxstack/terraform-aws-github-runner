#!/bin/bash -ex
# shellcheck disable=SC2154,SC2034,SC2128,SC2155,SC2206,SC2207,SC2046,SC2068,SC2125,SC1083
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# --- configurations --------------------------

GHR_CORE_CONFIG_RUN_AS=ec2-user
GHR_CORE_WORK_DIRECTORY=/mnt/ephemeral/action-runner/work
GHR_PACKAGE_S3_SOURCE_PATH="${s3_location_runner_distribution}"
GHR_PACKAGE_FILENAME=actions-runner.tar.gz
GHR_SYS_ARCHITECTURE=$(uname -p)
GHR_SYS_OS=$( ( lsb_release -ds || cat /etc/*release || uname -om ) 2>/dev/null | head -n1 | cut -d "=" -f2- | tr -d '"' )
GHR_SYS_OS_ID=$(awk -F= '/^ID/{print $2}' /etc/os-release)

export RAID_NAME=ephemeral_raid
export RAID_DEVICE=/dev/md0
export RAID_MOUNT_PATH=/mnt/ephemeral

# --- functions -------------------------------

function list_instance_stores {
  if [[ -e /dev/nvme0n1 ]]; then
    local instance_stores=($(nvme list | awk '/Instance Storage/ {print $1}'))
  else
    local OSDEVICE=$(sudo lsblk -o NAME -n | grep -v '[[:digit:]]' | sed "s/^sd/xvd/g")
    local BDMURL="http://169.254.169.254/latest/meta-data/block-device-mapping/"
    local instance_stores=()
    for bd in $(curl -s $${BDMURL}); do
      MAPDEVICE=$(curl -s $${BDMURL}/"$${bd}"/ | sed "s/^sd/xvd/g");
      if grep -wq "$${MAPDEVICE}" <<< "$${OSDEVICE}"; then
        instance_stores+=($MAPDEVICE)
      fi
    done
  fi
  echo "$${instance_stores[@]}"
}
export -f list_instance_stores

function provision_instance_stores {
  devices=($(list_instance_stores))
  count=$${#devices[@]}

  mkdir -p $RAID_MOUNT_PATH
  if [[ $count -eq 1 ]]; then
    mkfs.ext4 "$devices"
    echo "$devices" $${RAID_MOUNT_PATH} ext4 defaults,noatime 0 2 >> /etc/fstab
  elif [[ $count -gt 1 ]]; then
    mdadm --create --verbose --level=0 $RAID_DEVICE --auto=yes --name=$RAID_NAME --raid-devices="$${count}" $${devices[@]}
    while [[ $(mdadm -D $RAID_DEVICE) != *"State : clean"* ]] && [[ $(mdadm -D $RAID_DEVICE) != *"State : active"* ]]; do
      sleep 1
    done
    mkfs.ext4 $RAID_DEVICE
    mdadm --detail --scan >> /etc/mdadm.conf
    dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r)
    echo $RAID_DEVICE $RAID_MOUNT_PATH ext4 defaults,noatime 0 2 >> /etc/fstab
  fi
  mount -a
}
export -f provision_instance_stores

# --- install: core -----------------------------

yum upgrade -y

dnf install -y docker

yum install --allowerasing -y \
  amazon-cloudwatch-agent \
  curl \
  dotnet-sdk-6.0 \
  git \
  gnupg2 \
  jq \
  make \
  mdadm \
  nvme-cli \
  python-pip

provision_instance_stores

AWS_EC2_METADATA_TOKEN=$(curl -f -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 180")
AWS_REGION=$(curl -f -H "X-aws-ec2-metadata-token: $AWS_EC2_METADATA_TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
AWS_INSTANCE_ID=$(curl -f -H "X-aws-ec2-metadata-token: $AWS_EC2_METADATA_TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)
AWS_INSTANCE_AMI_ID=$(curl -f -H "X-aws-ec2-metadata-token: $AWS_EC2_METADATA_TOKEN" -v http://169.254.169.254/latest/meta-data/ami-id)
AWS_INSTANCE_AZ=$(curl -f -H "X-aws-ec2-metadata-token: $AWS_EC2_METADATA_TOKEN" -v http://169.254.169.254/latest/meta-data/placement/availability-zone)
AWS_INSTANCE_TAGS=$(aws ec2 describe-tags --region "$AWS_REGION" --filters "Name=resource-id,Values=$AWS_INSTANCE_ID")
AWS_INSTANCE_TYPE=$(curl -f -H "X-aws-ec2-metadata-token: $AWS_EC2_METADATA_TOKEN" -v http://169.254.169.254/latest/meta-data/instance-type)

# --- configure: docker ---------------------------

DOCKER_CONFIG_SECRET_NAME=$(echo "$AWS_INSTANCE_TAGS" | jq -r '.Tags[]  | select(.Key == "ghr:docker_config_sm_secret_name") | .Value')
DOCKER_CONFIG_SECRET=$(aws secretsmanager get-secret-value --secret-id "$DOCKER_CONFIG_SECRET_NAME" --query SecretString --output text)

service docker stop
service docker.socket stop
service containerd stop
mkdir -p $RAID_MOUNT_PATH/docker
mv /var/lib/docker $RAID_MOUNT_PATH
echo "{\"data-root\":\"$RAID_MOUNT_PATH/docker\"}" > /etc/docker/daemon.json
service docker start
usermod -a -G docker ec2-user

# loop through each login
echo "$DOCKER_CONFIG_SECRET" | jq -c '.logins[]' | while read DOCKER_LOGIN; do
    if [[ -z "$DOCKER_LOGIN" ]]; then continue; fi
    DOCKER_LOGIN_USER=$(echo "$DOCKER_LOGIN" | jq -r '.user')
    DOCKER_LOGIN_PASS=$(echo "$DOCKER_LOGIN" | jq -r '.pass')
    DOCKER_LOGIN_SERVER=$(echo "$DOCKER_LOGIN" | jq -r '.server')
    echo "$DOCKER_LOGIN_PASS" | docker login --username "$DOCKER_LOGIN_USER" --password-stdin "$DOCKER_LOGIN_SERVER"

    unset DOCKER_LOGIN_USER
    unset DOCKER_LOGIN_PASS
    unset DOCKER_LOGIN_SERVER
done

# --- install: runner -----------------------------

mkdir -p /opt/hostedtoolcache
mkdir -p /opt/actions-runner
mkdir -p "$GHR_PACKAGE_S3_SOURCE_PATH"

echo "changing to gh runner directory..."
cd /opt/actions-runner

echo "downloading gh runner from s3 bucket $GHR_PACKAGE_S3_SOURCE_PATH..."
aws s3 cp "$GHR_PACKAGE_S3_SOURCE_PATH" "$GHR_PACKAGE_FILENAME" --region "$AWS_REGION"
tar xzf ./$GHR_PACKAGE_FILENAME
rm -rf $GHR_PACKAGE_FILENAME

if [[ "$GHR_SYS_ARCHITECTURE" == "arm" ]] || [[ "$GHR_SYS_ARCHITECTURE" == "arm64" ]]; then
  yum install -y libicu60
fi

if [[ "$GHR_SYS_OS_ID" =~ ^ubuntu.* ]]; then
  ./bin/installdependencies.sh
fi

echo "set file ownership of action runner..."
chown -R "$GHR_CORE_CONFIG_RUN_AS":"$GHR_CORE_CONFIG_RUN_AS" .
chown -R "$GHR_CORE_CONFIG_RUN_AS":"$GHR_CORE_CONFIG_RUN_AS" /opt/hostedtoolcache

# --- configure: runner -------------------------

GHR_SSM_PATH_PREFIX=$(echo "$AWS_INSTANCE_TAGS" | jq -r '.Tags[]  | select(.Key == "ghr:ssm_config_path") | .Value')
GHR_ENVIRONMENT=$(echo "$AWS_INSTANCE_TAGS" | jq -r '.Tags[]  | select(.Key == "ghr:environment") | .Value')
GHR_CORE_CONFIG=$(aws ssm get-parameters-by-path --path "$GHR_SSM_PATH_PREFIX" --region "$AWS_REGION" --query "Parameters[*].{Name:Name,Value:Value}")
GHR_CORE_CONFIG_RUN_AS=$(echo "$GHR_CORE_CONFIG" | jq --arg GHR_SSM_PATH_PREFIX "$GHR_SSM_PATH_PREFIX" -r '.[] | select(.Name == "\($GHR_SSM_PATH_PREFIX)/run_as") | .Value')
GHR_CORE_CONFIG_GW_AGENT_ENABLED=$(echo "$GHR_CORE_CONFIG" | jq --arg GHR_SSM_PATH_PREFIX "$GHR_SSM_PATH_PREFIX" -r '.[] | select(.Name == "\($GHR_SSM_PATH_PREFIX)/enable_cloudwatch") | .Value')
GHR_CORE_CONFIG_AGENT_MODE=$(echo "$GHR_CORE_CONFIG" | jq --arg GHR_SSM_PATH_PREFIX "$GHR_SSM_PATH_PREFIX" -r '.[] | select(.Name == "\($GHR_SSM_PATH_PREFIX)/agent_mode") | .Value')
GHR_CORE_CONFIG_TOKEN_PATH=$(echo "$GHR_CORE_CONFIG" | jq --arg GHR_SSM_PATH_PREFIX "$GHR_SSM_PATH_PREFIX" -r '.[] | select(.Name == "\($GHR_SSM_PATH_PREFIX)/token_path") | .Value')

if [[ "$GHR_CORE_CONFIG_GW_AGENT_ENABLED" == "true" ]]; then
  echo "enabling cloudwatch..."
  amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "ssm:$GHR_SSM_PATH_PREFIX/cloudwatch_agent_config_runner"
fi

while [[ -z "$GHR_CONFIG" ]]; do
  echo "waiting on gh runner configuration to be posted..."
  sleep 1
  GHR_CONFIG=$(aws ssm get-parameters --name "$GHR_CORE_CONFIG_TOKEN_PATH/$AWS_INSTANCE_ID" --with-decryption --region "$AWS_REGION" | jq -r ".Parameters | .[0] | .Value")
done
aws ssm delete-parameter --name "$GHR_CORE_CONFIG_TOKEN_PATH/$AWS_INSTANCE_ID" --region "$AWS_REGION"

chown -R "$GHR_CORE_CONFIG_RUN_AS" .

if [ -z "$GHR_CORE_CONFIG_RUN_AS" ]; then
  GHR_CORE_CONFIG_RUN_AS="ec2-user"
elif [[ "$GHR_CORE_CONFIG_RUN_AS" == "root" ]]; then
  export RUNNER_ALLOW_RUNASROOT=1
fi


tee /opt/actions-runner/.setup_info <<EOL
[{
  "group": "Operating System",
  "detail": "Distribution: $GHR_SYS_OS\nArchitecture: $GHR_SYS_ARCHITECTURE"
}, {
  "group": "Runner Image",
  "detail": "AMI id: $AWS_INSTANCE_AMI_ID"
},{
  "group": "EC2",
  "detail": "Instance type: $AWS_INSTANCE_TYPE\nAvailability zone: $AWS_INSTANCE_AZ"
}]
EOL

echo "creating ephemeral script..."
cat >/opt/start-runner-service.sh <<-EOF
  sudo --preserve-env=RUNNER_ALLOW_RUNASROOT -u "$GHR_CORE_CONFIG_RUN_AS" -- ./run.sh --jitconfig $${GHR_CONFIG}
  echo "runner is cleaning up..."
  echo "stopping cloudwatch service..."
  systemctl stop amazon-cloudwatch-agent.service
  echo "terminating instance..."
  aws ec2 terminate-instances --instance-ids "$AWS_INSTANCE_ID" --region "$AWS_REGION"
EOF
chmod 755 /opt/start-runner-service.sh

# --- start: runner -----------------------------

echo "starting runner after $(awk '{print int($1/3600)":"int(($1%3600)/60)":"int($1%60)}' /proc/uptime)"

if [[ $GHR_CORE_CONFIG_AGENT_MODE == "ephemeral" ]]; then
  echo "starting runner as user $GHR_CORE_CONFIG_RUN_AS in ephemeral mode..."
  nohup /opt/start-runner-service.sh &
else
  sudo --preserve-env=RUNNER_ALLOW_RUNASROOT -u "$GHR_CORE_CONFIG_RUN_AS" -- ./config.sh --unattended --name "$AWS_INSTANCE_ID" --work "$GHR_CORE_WORK_DIRECTORY" $${GHR_CONFIG}
  echo "starting runner as user $GHR_CORE_CONFIG_RUN_AS..."
  ./svc.sh install "$GHR_CORE_CONFIG_RUN_AS"
  ./svc.sh start
fi
