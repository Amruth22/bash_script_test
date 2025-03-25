#!/bin/bash

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed."
    exit 1
fi

# Check if user is logged in to Azure
if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure. Run 'az login' first."
    exit 1
fi

# Path to the file containing storage account names
file_path="$1"

if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
    echo "Error: Invalid file path. Usage: ./check_storage.sh storage_accounts.txt"
    exit 1
fi

echo "STORAGE ACCOUNT,HNS STATUS,BLOB SOFT DELETE"

# List all subscriptions
subscriptions=$(az account list --query "[].id" -o tsv)

# Read each line from the file and check storage account properties
while IFS= read -r storage_account || [[ -n "$storage_account" ]]; do
    # Skip empty lines
    if [ -z "$storage_account" ] || [[ "$storage_account" =~ ^# ]]; then
        continue
    fi
    
    # Remove whitespace
    storage_account=$(echo "$storage_account" | tr -d '[:space:]')
    found=false
    
    # Check in each subscription
    for subscription in $subscriptions; do
        # Set the active subscription
        az account set --subscription "$subscription" > /dev/null
        
        # Try to get storage account properties
        storage_info=$(az storage account show --name "$storage_account" 2>/dev/null)
        
        if [ -n "$storage_info" ]; then
            # Extract HNS status
            is_hns_enabled=$(echo "$storage_info" | jq -r '.isHnsEnabled')
            
            # Get resource group for further queries
            resource_group=$(echo "$storage_info" | jq -r '.resourceGroup')
            
            # Set soft delete status as "CHECKING" initially
            soft_delete_status="CHECKING"
            
            # Only check blob soft delete if HNS is disabled
            if [ "$is_hns_enabled" = "false" ]; then
                # Get blob service properties including soft delete
                blob_properties=$(az storage account blob-service-properties show --account-name "$storage_account" --resource-group "$resource_group" 2>/dev/null)
                
                if [ -n "$blob_properties" ]; then
                    # Extract soft delete status and retention days
                    is_soft_delete_enabled=$(echo "$blob_properties" | jq -r '.deleteRetentionPolicy.enabled')
                    
                    if [ "$is_soft_delete_enabled" = "true" ]; then
                        retention_days=$(echo "$blob_properties" | jq -r '.deleteRetentionPolicy.days')
                        soft_delete_status="ENABLED ($retention_days days)"
                    else
                        soft_delete_status="DISABLED"
                    fi
                else
                    soft_delete_status="ERROR"
                fi
            else
                # If HNS is enabled, we don't check soft delete
                soft_delete_status="N/A (HNS enabled)"
            fi
            
            # Output results
            if [ "$is_hns_enabled" = "true" ]; then
                echo "$storage_account,ENABLED,$soft_delete_status"
            else
                echo "$storage_account,DISABLED,$soft_delete_status"
            fi
            
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo "$storage_account,NOT FOUND,NOT FOUND"
    fi
    
done < "$file_path"
