#!/bin/bash
cd "$(dirname "$0")/.."
set -e
swift Tests/test_processor.swift
mkdir -p build
swiftc -target arm64-apple-macosx14.0 \
    -D PRACTICE_STORE_TESTS \
    Tests/test_practice_bank.swift \
    Domain/Practice/PracticeLogic.swift \
    Infrastructure/Practice/PracticeBankLoader.swift \
    Infrastructure/Practice/PracticeStore.swift \
    -o build/test_practice_bank
./build/test_practice_bank
