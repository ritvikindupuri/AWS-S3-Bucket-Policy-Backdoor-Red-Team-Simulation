# This script automates the full Stratus Red Team lifecycle for the S3 backdoor technique. It warms up, detonates, verifies, reverts, verifies again, and cleans up, all in one execution.

#!/bin/bash

# A script to automate the full lifecycle of the Stratus Red Team S3 backdoor simulation.

TECHNIQUE="aws.exfiltration.s3-backdoor-bucket-policy"

echo "--- Starting Stratus Red Team Simulation: $TECHNIQUE ---"

# --- Step 1: Warmup ---
echo ""
echo " Warming up the technique (Terraform apply)..."
stratus warmup $TECHNIQUE

# --- Step 2: Detonate ---
echo ""
echo " Detonating the technique (Applying malicious policy)..."
stratus detonate $TECHNIQUE
BUCKET_NAME=$(stratus show $TECHNIQUE --output terraform-output | grep "bucket_name" | awk '{print $3}' | tr -d '"')
echo "Target bucket identified: $BUCKET_NAME"

# --- Step 3: Verify Attack ---
echo ""
echo "🔍 Verifying successful detonation (checking for malicious policy)..."
aws s3api get-bucket-policy --bucket "$BUCKET_NAME"
if [ $? -eq 0 ]; then
    echo " SUCCESS: Malicious bucket policy is active."
else
    echo " FAILURE: Could not retrieve bucket policy."
fi

# --- Step 4: Revert ---
echo ""
echo "🛡 Reverting the technique (Removing malicious policy)..."
stratus revert $TECHNIQUE

# --- Step 5: Verify Revert ---
echo ""
echo " Verifying successful reversion (checking for policy removal)..."
aws s3api get-bucket-policy --bucket "$BUCKET_NAME"
if [ $? -ne 0 ]; then
    echo " SUCCESS: Malicious bucket policy has been removed."
else
    echo " FAILURE: Malicious policy still exists."
fi

# --- Step 6: Cleanup ---
echo ""
echo " Cleaning up all infrastructure (Terraform destroy)..."
stratus cleanup $TECHNIQUE

echo ""
echo "--- Simulation Complete ---"
