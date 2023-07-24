#!/bin/bash
echo "Waiting for API to Finish Setting Up..."
# sleep 630
echo "Waiting finishing...Starting APP SETUP"

# Filter to get instance_id -> EIP of API-EC2
instance_name="ec2-api"
echo "Retrieving instance ID..."
instance_id=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)
echo "$instance_id"

echo "Retrieving API Public IP..."
api_public_ip=$(aws ec2 describe-addresses \
  --filters "Name=instance-id,Values=$instance_id" \
  --query "Addresses[0].PublicIp" \
  --output text)
echo "$api_public_ip"

# Update the API_URL in config.json
echo "Updating apiUrl in config.json..."
sudo sed -i "s~API_URL~${api_public_ip}~" /home/ec2-user/src/config.json
# New apiUrl in config.json
cat /home/ec2-user/src/config.json

sleep 15

# Download Node.js and Install Dependencies
echo "Installing Dependencies and Node.js"
sudo yum update -y
sudo yum install -y nodejs npm

# Add Node Options for openssl
echo "Setting NODE_OPTIONS..."
export NODE_OPTIONS=--openssl-legacy-provider
echo "Finished Waiting...Installing Dependencies..."
sleep 10

# Installing npm Dependencies
echo "Installing NPM Dependencies"
cd /home/ec2-user/
npm install
sleep 30
echo "Installed Dependencies SUCCESS"

# ----------------------- WITHIN /HOME/EC2-USER/ DIRECTORY ----------------------------- #
#  npm start
# echo "Starting APP"
# sudo npm run start

# Build your app (output files will be in the build/ directory)
echo "Building APP"
npm run build
echo "Building APP, Finished."
# echo "Prepping APP for Use"
# npx serve -s build

# Automatically answer "yes" to all prompts during npm installation
sudo npm install -g serve -yes
serve -s build
