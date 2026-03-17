#!/bin/bash

# Test script for conversation history feature
# This script tests the new ? and ?? commands

# Source the plugin to make functions available
source ./aicli.plugin.zsh

echo "Testing conversation history feature..."
echo "======================================"

# First, let's check if our new functions exist
echo "Checking if new functions are defined..."
if ! declare -f _aicli_newchat >/dev/null 2>&1; then
    echo "ERROR: _aicli_newchat function not found"
    exit 1
fi

if ! declare -f _aicli_followup >/dev/null 2>&1; then
    echo "ERROR: _aicli_followup function not found"
    exit 1
fi

echo "✓ New functions are properly defined"

# Check if aliases are set
echo "Checking aliases..."
if ! alias \? >/dev/null 2>&1; then
    echo "ERROR: ? alias not found"
    exit 1
fi

if ! alias '??' >/dev/null 2>&1; then
    echo "ERROR: ?? alias not found"
    exit 1
fi

echo "✓ Aliases are properly set"

# Check if history functions exist
echo "Checking history functions..."
if ! declare -f _read_history >/dev/null 2>&1; then
    echo "ERROR: _read_history function not found"
    exit 1
fi

if ! declare -f _write_history >/dev/null 2>&1; then
    echo "ERROR: _write_history function not found"
    exit 1
fi

if ! declare -f _clear_history >/dev/null 2>&1; then
    echo "ERROR: _clear_history function not found"
    exit 1
fi

echo "✓ History functions are properly defined"

# Test file creation
echo "Testing history file creation..."
rm -f ~/.aicli_history.json

# Test that history file is created when needed
_aicli_newchat "test message" >/dev/null 2>&1

if [[ -f ~/.aicli_history.json ]]; then
    echo "✓ History file created successfully"
else
    echo "ERROR: History file was not created"
    exit 1
fi

# Check file content
content=$(cat ~/.aicli_history.json)
if [[ "$content" == "[]" ]]; then
    echo "✓ History file is empty initially"
else
    echo "INFO: History file content: $content"
fi

# Test corrupted history recovery
echo "Testing history file corruption recovery..."
echo '{invalid: json}' > ~/.aicli_history.json
_aicli_newchat "test" >/dev/null 2>&1
if [[ $(cat ~/.aicli_history.json) == '[]' ]]; then
    echo "✓ Corrupted history was reset successfully"
else
    echo "ERROR: Corruption recovery failed!"
    exit 1
fi

echo "Test completed successfully!"
