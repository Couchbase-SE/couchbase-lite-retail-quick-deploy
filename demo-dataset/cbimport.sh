#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

echo "Reading Terraform outputs..."
CONN_STRING=$(cd "$ROOT_DIR" && terraform output -raw connection_string)
PASSWORD=$(cd "$ROOT_DIR" && terraform output -raw db_credential_password)
USERNAME="simple-retail"
BUCKET="supermarket"

echo "Importing data into: $CONN_STRING"

# import <scope> <collection> <file>
# Keys come from each document's "id" field, so re-running updates documents
# instead of creating duplicates.
import() {
  echo "-> $1.$2 <- $3"
  cbimport json --format list \
    --cluster "couchbases://$CONN_STRING" \
    --username "$USERNAME" \
    --password "$PASSWORD" \
    --bucket "$BUCKET" \
    --scope-collection-exp "$1.$2" \
    --dataset "file://$SCRIPT_DIR/$3" \
    --generate-key "%id%"
}

for store in aa nyc; do
  case "$store" in
    aa)  scope="AA-Store" ;;
    nyc) scope="NYC-Store" ;;
  esac

  import "$scope" inventory         "${store}_store_inventory.json"
  import "$scope" profile           "${store}-store-01-profile.json"
  import "$scope" product_knowledge "${store}_store_product_knowledge.json"
  import "$scope" planograms        "${store}_store_planograms.json"
done

# "orders" starts empty; the app writes to it.
