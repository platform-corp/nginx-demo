#!/bin/bash

config_dir=${1:-"/usr/local/etc/provisioner"}  # Directory containing the configuration files
env_file="${config_dir}/provisioner.cfg"  # Path to the environment file
whitelist=( "/var" "/usr/local/etc/services" "/usr/local/share/services" )  # List of allowed base directories

while [[ ! -s "${env_file}" ]]; do
    echo "Waiting for environment file to be ready..."
    sleep 10  # Wait for 10 seconds before checking again
done

# Load environment variables from the file
source "${env_file}"

# Export any variables that match the pattern
for var in $(compgen -v PRV_GIT_); do
    export $var
done

# Get the number of repository configurations
num_of_repos=$(env | grep -E "^PRV_GIT_REPO_" | wc -l)

is_allowed_path() {
    local path="$1"
    for allowed in "${whitelist[@]}"; do
        if [[ "$path" == "$allowed"* ]]; then
            return 0  
        fi
    done
    return 1  
}

# Loop through each repository configuration
for i in $(seq 1 $num_of_repos); do
    # Define the environment variables for the repository, destination, branch, and update
    repo_var="PRV_GIT_REPO_$i"
    dest_var="PRV_GIT_DESTINATION_$i"
    branch_var="PRV_GIT_BRANCH_$i"
    # command_var="PRV_GIT_COMMAND_$i"
    containerization_var="PRV_GIT_CONTAINERIZATION_$i"
    update_var="PRV_GIT_UPDATE_$i"

    # Get the values of the repository, destination, branch, and update variables
    repo=${!repo_var}
    dest=${!dest_var}
    branch=${!branch_var}
    # command=${!command_var}
    containerization=${!containerization_var}
    update=${!update_var}

    # Check if both repo and destination variables are set
    if [[ -z "${repo}" || -z "${dest}" ]]; then
        echo "Missing configuration for $repo_var or $dest_var."
        continue  # Skip this iteration if the configuration is incomplete
    fi

    # Extract the base directory of the destination path
    base_dir=$(dirname "${dest}")

    # Check if the base directory is in the whitelist
    if ! is_allowed_path "${base_dir}"; then
        log "Base directory ${base_dir} is not in the whitelist, skipping this repository..."
        continue
    fi

    # Check if the base directory exists, create it if not
    if [ ! -d "${base_dir}" ]; then
        echo "Base directory ${base_dir} does not exist, creating it..."
        mkdir -p "${base_dir}"
        if [ $? -ne 0 ]; then
            echo "Failed to create base directory ${base_dir}, skipping this repository..."
            continue  # Skip this iteration if unable to create the directory
        fi
    fi

    # Check if the destination directory exists, clone the repository if not
    if [ -d "${dest}" ]; then
        # Check if the update variable is set to on-each-boot or on-reload-config
        if [ "${update}" == "on-each-boot" ] || ([ "${update}" == "on-reload-config" ] && [ -f "${config_dir}/reload" ]); then
            rm -rf "${dest}"
        else
            echo "Directory ${dest} already exists, skipping..."
            continue  # Skip this iteration if the directory already exists
        fi
    fi

    echo "Cloning ${repo} into $dest..."
    # Check if a branch variable is set and use it; otherwise default to the main branch
    if [[ ! -z "${branch}" ]]; then
        git clone --depth 1 --branch "${branch}" "${repo}" "${dest}"
    else
        git clone --depth 1 "${repo}" "${dest}"
    fi
    if [ $? -ne 0 ]; then
        echo "Failed to clone ${repo}"
        continue
    fi

    # Remove the .git directory to delete all Git metadata
    rm -rf "${dest}/.git"
    if [ $? -ne 0 ]; then
        echo "Failed to remove .git directory in ${dest}"
    fi

    # Execute the command if set
    # if [[ ! -z "${command}" ]]; then
    #     echo "Executing command: ${command}"
    #     eval "${command}"
    #     if [ $? -ne 0 ]; then
    #         echo "Command execution failed for ${command}"
    #     fi
    # fi
    if [[ ! -z "${containerization}" ]]; then
        echo "Containerizing the service: ${containerization}"
        if [[ "${containerization}" == "docker" ]]; then
            /usr/bin/podman run \
                --rm \
                --privileged \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v ${dest}/compose:/config \
                -w /config docker:latest \
                compose -f docker-compose.yml up -d
            
        elif [[ "${containerization}" == "podman" ]]; then
            /usr/bin/podman run \
                --rm \
                --privileged \
                -v /var/run/podman/podman.sock:/var/run/docker.sock \
                -v ${dest}/compose:/config \
                -w /config docker:latest \
                compose -f docker-compose.yml up -d
        else
            echo "Unsupported containerization method: ${containerization}"
        fi
   fi
done

rm -f "${config_dir}/reload"  # Remove the reload file after processing
