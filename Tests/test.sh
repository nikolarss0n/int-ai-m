#!/bin/bash
cd "$(dirname "$0")/.."
set -e
mkdir -p build/processor-tests
cp Tests/test_processor.swift build/processor-tests/main.swift
swiftc -target arm64-apple-macosx14.0 \
    build/processor-tests/main.swift \
    Domain/Model/InterviewBriefing.swift \
    Domain/Model/ScreenshotPresentation.swift \
    Domain/Model/CodingInterviewSteps.swift \
    -o build/test_processor
./build/test_processor
swiftc -target arm64-apple-macosx14.0 \
    -D PRACTICE_STORE_TESTS \
    Tests/test_practice_bank.swift \
    Domain/Practice/PracticeLogic.swift \
    Infrastructure/Practice/PracticeBankLoader.swift \
    Infrastructure/Practice/PracticeStore.swift \
    -o build/test_practice_bank
./build/test_practice_bank
