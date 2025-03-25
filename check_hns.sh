#!/bin/bash

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Azure CLI is not installed. Please install it first."
    echo "You can install it using: brew install azure-cli"
    exit 1
fi

# Check if user is logged in to Azure
az account show &> /dev/null
if [ $? -ne 0 ]; then
    echo "You are not logged in to Azure. Please login first."
    echo "Run: az login"
    exit 1
fi

# Path to the file containing storage account names
file_path="$1"

if [ -z "$file_path" ]; then
    echo "Please provide the path to the file containing storage account names."
    echo "Usage: ./check_hns.sh path/to/storage_accounts.txt"
    exit 1
fi

if [ ! -f "$file_path" ]; then
    echo "File not found: $file_path"
    exit 1
fi

echo "Checking HNS status for storage accounts..."
echo "--------------------------------------------"

# Read each line from the file and check HNS status
while IFS= read -r storage_account || [[ -n "$storage_account" ]]; do
    # Skip empty lines
    if [ -z "$storage_account" ]; then
        continue
    fi
    
    # Remove any whitespace
    storage_account=$(echo "$storage_account" | tr -d '[:space:]')
    
    echo "Checking: $storage_account"
    
    # Get resource group name for the storage account
    resource_group=$(az storage account show --name "$storage_account" --query "resourceGroup" -o tsv 2>/dev/null)
    
    if [ -z "$resource_group" ]; then
        echo "  Error: Storage account '$storage_account' not found or access denied."
        continue
    fi
    
    # Check if HNS is enabled
    is_hns_enabled=$(az storage account show --name "$storage_account" --resource-group "$resource_group" --query "isHnsEnabled" -o tsv)
    
    if [ "$is_hns_enabled" = "true" ]; then
        echo "  Status: HNS is ENABLED"
    else
        echo "  Status: HNS is DISABLED"
    fi
    
done < "$file_path"

echo "--------------------------------------------"
echo "Check completed"