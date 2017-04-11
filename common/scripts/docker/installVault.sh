#!/bin/bash -e

export COMPONENT="vault"
export VAULT_DATA_DIR="$RUNTIME_DIR/$COMPONENT/data"
export VAULT_CONFIG_DIR="$CONFIG_DIR/$COMPONENT"
export VAULT_IMAGE="library/vault:0.6.0"
export VAULT_MOUNTS="$VAULT_MOUNTS"
export SCRIPTS_DIR="$SCRIPTS_DIR"
export DB_USER=apiuser
export DB_NAME=shipdb
export VAULT_URL="http://172.17.0.1:8200"

__validate_vault_envs() {
  __process_msg "Initializing vault environment variables"
  __process_msg "SCRIPTS_DIR: $SCRIPTS_DIR"
  __process_msg "VAULT_DATA_DIR: $VAULT_DATA_DIR"
  __process_msg "VAULT_CONFIG_DIR: $VAULT_CONFIG_DIR"
}

__validate_vault_mounts() {
  __process_msg "Validating vault mounts"
  if [ ! -d "$VAULT_DATA_DIR" ]; then
    __process_msg "Creating data directory $VAULT_DATA_DIR"
    sudo mkdir -p $VAULT_DATA_DIR
  else
    __process_msg "Data directory already present: $VAULT_DATA_DIR"
  fi

  if [ ! -d "$VAULT_CONFIG_DIR" ]; then
    __process_msg "Creating config directory $VAULT_CONFIG_DIR"
    sudo mkdir -p $VAULT_CONFIG_DIR
  else
    __process_msg "Config directory already present: $VAULT_CONFIG_DIR"
  fi

  sudo mkdir -p $VAULT_CONFIG_DIR/scripts
}

__update_vault_config() {
  __process_msg "Generating vault config"
  cp -vr $SCRIPTS_DIR/configs/vault_config.hcl.template $VAULT_CONFIG_DIR/config.hcl
  cp -vr $SCRIPTS_DIR/configs/policy.hcl $VAULT_CONFIG_DIR/scripts/policy.hcl
  cp -vr $SCRIPTS_DIR/configs/vaultToken.json.template $VAULT_CONFIG_DIR/scripts/vaultToken.json.template
  cp -vr $SCRIPTS_DIR/docker/initializeVault.sh $VAULT_CONFIG_DIR/scripts/initializeVault.sh
}

__run_vault() {
  __process_msg "Running vault container"
  local data_dir_container="/var/run/vault"
  local config_dir_container="/vault/config"

  local run_cmd="sudo docker run \
    -d \
    -v $VAULT_DATA_DIR:$data_dir_container \
    -v $VAULT_CONFIG_DIR:$config_dir_container \
    --publish 8200:8200 \
    --privileged=true \
    --name=$COMPONENT \
    $VAULT_IMAGE server
  "

  eval "$run_cmd"
  __process_msg "Vault container successfully running"
}

__initialize_vault() {
  __process_msg "Initialize vault"

  local bootstrap_cmd="sudo docker exec \
    vault sh -c '/vault/config/scripts/initializeVault.sh'"
  __process_msg "Executing: $bootstrap_cmd"
  eval "$bootstrap_cmd"

  local vault_token_file="$VAULT_CONFIG_DIR/scripts/vaultToken.json"
  if [ ! -f "$vault_token_file" ]; then
    __process_error "No vault token file present, exiting"
    exit 1
  else
    local vault_token=$(cat "$vault_token_file" \
      | jq -r '.vaultToken')
    __process_msg "Generated vault token: $vault_token"
  fi

  sudo docker exec db \
    psql -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1 \
    -c "UPDATE \"systemConfigs\" set \"vaultToken\"='$vault_token'"

  sudo docker exec db \
    psql -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1 \
    -c "UPDATE \"systemConfigs\" set \"vaultUrl\"='$VAULT_URL'"

  __process_msg "Bootstrap vault complete"
}

main() {
  __process_marker "Booting Vault"
  if [ "$IS_INSTALLED" == true ]; then
    __process_msg "Vault already installed, skipping"
  else
    __process_msg "Vault not installed"
    __validate_vault_envs
    __validate_vault_mounts
    __update_vault_config
    __run_vault
  fi

  if [ "$IS_INITIALIZED" == true ]; then
    __process_msg "Vault already initialized, skipping"
  else
    __process_msg "Vault not initialized"
    __initialize_vault
  fi
  __process_msg "Vault container successfully running"
}

main