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
