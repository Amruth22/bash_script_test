#!/bin/bash

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Azure CLI is not installed. Please install it first."
    echo "You can install it using: brew install azure-cli"
    exit 1
fi

# Check if user is logged in to Azure
echo "Verifying Azure login..."
current_user=$(az account show --query "user.name" -o tsv 2>/dev/null)
if [ -z "$current_user" ]; then
    echo "You are not logged in to Azure. Please login first."
    echo "Run: az login"
    exit 1
else
    echo "Logged in as: $current_user"
fi

# Ensure Storage resource provider is registered
echo "Ensuring Storage resource provider is registered..."
az provider register --namespace Microsoft.Storage --wait > /dev/null

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

# List all subscriptions
echo "Fetching available subscriptions..."
subscriptions=$(az account list --query "[].{id:id,name:name}" --output json)
subscription_count=$(echo "$subscriptions" | jq '. | length')
echo "Found $subscription_count subscription(s)"

# Initialize summary counters
total_accounts=0
found_accounts=0
hns_enabled=0
hns_disabled=0
not_found=0

# Read each line from the file and check HNS status
while IFS= read -r storage_account || [[ -n "$storage_account" ]]; do
    # Skip empty lines or commented lines
    if [ -z "$storage_account" ] || [[ "$storage_account" =~ ^# ]]; then
        continue
    fi
    
    # Remove any whitespace
    storage_account=$(echo "$storage_account" | tr -d '[:space:]')
    
    # Increment counter
    ((total_accounts++))
    
    echo "[$total_accounts] Checking: $storage_account"
    found=false
    
    # Check in each subscription
    echo "$subscriptions" | jq -c '.[]' | while read -r subscription_json; do
        subscription_id=$(echo "$subscription_json" | jq -r '.id')
        subscription_name=$(echo "$subscription_json" | jq -r '.name')
        
        echo "  Checking in subscription: $subscription_name ($subscription_id)"
        
        # Set the active subscription
        az account set --subscription "$subscription_id" > /dev/null
        
        # Try to get resource group name for the storage account with detailed error capture
        resource_info=$(az storage account show --name "$storage_account" 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            # Extract needed information
            resource_group=$(echo "$resource_info" | jq -r '.resourceGroup')
            is_hns_enabled=$(echo "$resource_info" | jq -r '.isHnsEnabled')
            
            echo "  Found in subscription: $subscription_name"
            echo "  Resource group: $resource_group"
            
            # Check if HNS is enabled
            if [ "$is_hns_enabled" = "true" ]; then
                echo "  Status: HNS is ENABLED"
                ((hns_enabled++))
            else
                echo "  Status: HNS is DISABLED"
                ((hns_disabled++))
            fi
            
            ((found_accounts++))
            found=true
            break
        else
            # Check if it's an access error or not found error
            if [[ "$resource_info" == *"AuthorizationFailed"* ]]; then
                echo "  Access denied in this subscription"
            elif [[ "$resource_info" == *"ResourceNotFound"* ]]; then
                echo "  Not found in this subscription"
            else
                echo "  Error: $resource_info"
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo "  Error: Storage account '$storage_account' not found in any subscription or access denied."
        echo "  Recommended actions:"
        echo "    - Verify the storage account name is correct (case-sensitive)"
        echo "    - Check if you need to use a different Azure tenant/directory"
        echo "    - Try running 'az login --tenant YOUR_TENANT_ID' if using multiple tenants"
        echo "    - Verify the storage account still exists"
        ((not_found++))
    fi
    
    echo ""
    
done < "$file_path"

echo "--------------------------------------------"
echo "Summary:"
echo "  Total storage accounts checked: $total_accounts"
echo "  Found accounts: $found_accounts"
echo "  HNS enabled: $hns_enabled"
echo "  HNS disabled: $hns_disabled"
echo "  Not found accounts: $not_found"
echo "--------------------------------------------"
echo "Check completed"
