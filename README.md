# bash_script_test
Repository for testing bash scripts related to Azure CLI.

## Scripts Overview

### check_hns.sh
This script checks the Hierarchical Namespace (HNS) status for Azure storage accounts. It verifies if the Azure CLI is installed and if the user is logged in to Azure. It reads storage account names from a file and outputs their HNS status.

### check_hns_v2.sh
An enhanced version of `check_hns.sh`, this script includes subscription handling and provides a summary of the HNS status for storage accounts across multiple subscriptions.

### sura
This script checks the HNS status of storage accounts and outputs the results in a simplified format. It is designed for quick checks with minimal output.

### check_storage.sh
This script checks both the HNS status and Blob Soft Delete status for Azure storage accounts. It provides detailed information about each storage account, including whether Blob Soft Delete is enabled and the retention period.

### async_check_storage.sh
This script performs asynchronous checking of storage accounts with parallel processing. It checks both HNS and Blob Soft Delete statuses, utilizing multiple processes to handle large numbers of storage accounts efficiently.
