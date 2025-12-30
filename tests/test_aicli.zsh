#!/usr/bin/env zsh

# Test setup
FAILED=0

fail() {
    echo "❌ $1"
    FAILED=1
}

pass() {
    echo "✅ $1"
}

# Mock ZLE and bindkey to avoid errors when sourcing the plugin
zle() { :; }
bindkey() { :; }
autoload() { :; }

# Mock variables
AI_CLI_ENDPOINT="http://mock-endpoint"
AI_CLI_MODEL="mock-model"

# Source the plugin to test its functions
# We suppress output from the sourcing itself (like dependency checks)
source ./aicli.plugin.zsh >/dev/null 2>&1

# Mock curl
# We use a global variable to control what mock curl returns
MOCK_CURL_MODE=""
MOCK_CURL_OUTPUT=""
MOCK_CURL_EXIT_CODE=0

curl() {
    if [[ "$MOCK_CURL_MODE" == "fail" ]]; then
        return 7
    fi
    echo "$MOCK_CURL_OUTPUT"
    return 0
}

echo "Running tests for _aicli_call_llm..."

# TEST 1: Successful response
MOCK_CURL_MODE="success"
MOCK_CURL_OUTPUT='{"model":"mock","created_at":"2023-01-01","message":{"role":"assistant","content":"Hello world"},"done":true}'
output=$(_aicli_call_llm "prompt" "system")

if [[ "$output" == "Hello world" ]]; then
    pass "Success case"
else
    fail "Success case failed. Expected 'Hello world', got '$output'"
fi

# TEST 2: Curl connection failure
MOCK_CURL_MODE="fail"
MOCK_CURL_OUTPUT=""
output=$(_aicli_call_llm "prompt" "system")

if [[ "$output" == *"Connection failed"* ]]; then
    pass "Curl failure case"
else
    fail "Curl failure case failed. Expected 'Connection failed...', got '$output'"
fi

# TEST 3: Empty response
MOCK_CURL_MODE="success"
MOCK_CURL_OUTPUT=""
output=$(_aicli_call_llm "prompt" "system")

if [[ "$output" == *"Empty response"* ]]; then
    pass "Empty response case"
else
    fail "Empty response case failed. Expected 'Empty response...', got '$output'"
fi

# TEST 4: Ollama error field
MOCK_CURL_MODE="success"
MOCK_CURL_OUTPUT='{"error":"model not found"}'
output=$(_aicli_call_llm "prompt" "system")

if [[ "$output" == *"aicli error: model not found"* ]]; then
    pass "Ollama error case"
else
    fail "Ollama error case failed. Expected 'aicli error: model not found', got '$output'"
fi

# TEST 5: Malformed JSON
MOCK_CURL_MODE="success"
MOCK_CURL_OUTPUT='not json'
output=$(_aicli_call_llm "prompt" "system")

if [[ "$output" == *"Failed to parse response"* ]]; then
    pass "Malformed JSON case"
else
    fail "Malformed JSON case failed. Expected 'Failed to parse response...', got '$output'"
fi

echo "Running tests for _aicli_chat_request..."

# TEST 6: Chat request (verifies payload structure handling implicitly via mock)
MOCK_CURL_MODE="success"
MOCK_CURL_OUTPUT='{"model":"mock","created_at":"2023-01-01","message":{"role":"assistant","content":"I am a chat bot"},"done":true}'
# We pass a simple valid JSON array string
output=$(_aicli_chat_request '[{"role":"user","content":"hi"}]')

if [[ "$output" == "I am a chat bot" ]]; then
    pass "Chat request success case"
else
    fail "Chat request success case failed. Expected 'I am a chat bot', got '$output'"
fi

exit $FAILED
