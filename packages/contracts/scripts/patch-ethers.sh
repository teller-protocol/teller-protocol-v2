#!/bin/bash
# Patches hardhat-ethers to handle empty-string "to" in contract creation txs
# Fixes: "invalid value for value.to (invalid address, value="")"

HARDHAT_ETHERS_JS="$(dirname "$0")/../node_modules/@nomicfoundation/hardhat-ethers/internal/ethers-utils.js"

if [ -f "$HARDHAT_ETHERS_JS" ] && ! grep -q 'value.to === ""' "$HARDHAT_ETHERS_JS"; then
  sed -i '/Some clients (TestRPC)/i\    // Normalize empty-string "to" (contract creation) to null\n    if (value.to === "" || value.to === "0x") {\n        value.to = null;\n    }' "$HARDHAT_ETHERS_JS"
fi
