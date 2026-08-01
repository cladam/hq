#!/bin/bash
# Exit on error
set -e

# Rebuild hq first
echo "Rebuilding hq..."
rm -rf .koka
hica build -o hq

echo ""
echo "=== hq CLI Examples using examples/tbdflow.hml ==="
echo ""

echo "1. Query a top-level property (main-branch-name):"
echo "Command: ./hq '.main-branch-name' examples/tbdflow.hml"
./hq '.main-branch-name' examples/tbdflow.hml
echo ""

echo "2. Query a top-level property (main-branch-name) with raw output (-r):"
echo "Command: ./hq -r '.main-branch-name' examples/tbdflow.hml"
./hq -r '.main-branch-name' examples/tbdflow.hml
echo ""

echo "3. Query a nested element (@review |> elem(\"labels\") |> prop(\"pending\")):"
echo "Command: ./hq '@review |> elem(\"labels\") |> prop(\"pending\")' examples/tbdflow.hml"
./hq '@review |> elem("labels") |> prop("pending")' examples/tbdflow.hml
echo ""

echo "4. Query a nested element with raw output (-r):"
echo "Command: ./hq -r '@review |> elem(\"labels\") |> prop(\"pending\")' examples/tbdflow.hml"
./hq -r '@review |> elem("labels") |> prop("pending")' examples/tbdflow.hml
echo ""

echo "5. Query list configurations (@lint |> elem(\"conventional-commit-type\") |> prop(\"allowed-types\")):"
echo "Command: ./hq '@lint |> elem(\"conventional-commit-type\") |> prop(\"allowed-types\")' examples/tbdflow.hml"
./hq '@lint |> elem("conventional-commit-type") |> prop("allowed-types")' examples/tbdflow.hml
echo ""

echo "6. Select the 2nd (index 1) ingress rule from Terraform config:"
echo "Command: ./hq '@ingress-rules |> [1]' examples/terraform.hml"
./hq '@ingress-rules |> [1]' examples/terraform.hml
echo ""

echo "7. Select the first 2 ingress rules from Terraform config:"
echo "Command: ./hq '@ingress-rules |> take(2)' examples/terraform.hml"
./hq '@ingress-rules |> take(2)' examples/terraform.hml
echo ""

echo "8. Extract a multi-line user-data script from Terraform config (raw mode):"
echo "Command: ./hq -r '.user-data-script' examples/terraform.hml"
./hq -r '.user-data-script' examples/terraform.hml
echo ""

echo "9. Extract containerPort from K8s Deployment spec:"
echo "Command: ./hq '@spec |> elem(\"template\") |> elem(\"spec\") |> elem(\"containers\") |> elem(\"ports\") |> elem(\"ports\") |> prop(\"containerPort\")' examples/k8s.hml"
./hq '@spec |> elem("template") |> elem("spec") |> elem("containers") |> elem("ports") |> elem("ports") |> prop("containerPort")' examples/k8s.hml
echo ""
