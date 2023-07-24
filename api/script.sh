#!/bin/bash
# Fetch the configuration endpoint of the ElastiCache replication group
redis_endpoint=$(aws elasticache describe-replication-groups \
  --replication-group-id "$replication_group_id" \
  --query "ReplicationGroups[0].ConfigurationEndpoint.Address" \
  --output text)

# Append the Redis port to the Redis host
REDIS_HOST="$redis_endpoint:6379"
# Export the REDIS_HOST environment variable
export REDIS_HOST
echo "The Following Info is for the API <-> REDIS Connection:"
echo "REDIS_HOST: $REDIS_HOST"

sleep 15

# Update package list and install required dependencies
echo "Updating dependencies..."
sudo yum update
sudo yum groupinstall -y "Development Tools"
echo "Install of dependencies SUCCESS!!!"

# Install Rust using rustup
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
sleep 15
echo "Installed Rust SUCCESS!!!"

# Add Rust binaries to the PATH
echo "Configuring Current Shell to HOME/.cargo/env"
source $HOME/.cargo/env

cd /home/ec2-user

# Build the API in release mode
echo "Building the API..."
cargo build --release
echo "API build SUCCESSFUL!!!"

# Start the API using cargo
echo "Starting the API..."
cargo run #--release
echo "API started SUCCESSFULLY!!!"
