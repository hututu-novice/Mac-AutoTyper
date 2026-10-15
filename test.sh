#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
swiftc -o .build/model-tests src/TypingModel.swift tests/ModelTests.swift
.build/model-tests
swiftc -o .build/target-policy-tests src/QuarkTarget.swift tests/TargetPolicyTests.swift -framework AppKit -framework ApplicationServices
.build/target-policy-tests
