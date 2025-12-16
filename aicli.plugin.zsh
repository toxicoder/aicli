# Configuration
: ${AI_CLI_MODEL:="qwen2.5-coder:7b"}
: ${AI_CLI_ENDPOINT:="http://localhost:11434/api/chat"}
: ${AI_CLI_DEBOUNCE:=0.5}

# Check dependencies
if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "aicli: curl and jq are required."
    return
fi

# Helper function to call Ollama
_aicli_call_llm() {
    local prompt="$1"
    local system_prompt="$2"

    # Construct JSON payload
    local json_payload=$(jq -n \
        --arg model "$AI_CLI_MODEL" \
        --arg sys "$system_prompt" \
        --arg msg "$prompt" \
        '{model: $model, messages: [
            {role: "system", content: $sys},
            {role: "user", content: $msg}
        ], stream: false}')

    # Call curl
    # Silence curl errors to avoid UI disruption
    local response=$(curl -s -X POST "$AI_CLI_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>/dev/null)

    # Extract content
    # Handle empty response if curl failed
    if [[ -n "$response" ]]; then
        echo "$response" | jq -r '.message.content' 2>/dev/null
    fi
}

# Feature 2: Quick Chat Query
function _aicli_chat() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: ? <query>"
        return 1
    fi

    local query="$*"
    local context_pwd="$PWD"

    local system_prompt="You are a concise terminal expert. Provide the exact command(s) for: $query. Include brief flag explanations if helpful. Output only commands and short notes—no chit-chat. Current directory: $context_pwd"

    printf "Querying AI..."
    local result=$(_aicli_call_llm "$query" "$system_prompt")

    printf "\r\033[K" # Clear current line
    echo "$result"
}
# Alias ? to _aicli_chat with noglob to avoid globbing conflicts
alias \?='noglob _aicli_chat'


# Feature 3: Command Explanation
_aicli_explain_widget() {
    local buffer_content="$BUFFER"
    if [[ -z "$buffer_content" ]]; then
        zle -M "No command to explain."
        return
    fi

    zle -M "Asking AI to explain..."

    local system_prompt="Explain this command briefly, including what each flag does. Be concise."
    local explanation=$(_aicli_call_llm "$buffer_content" "$system_prompt")

    zle -M "$explanation"
}

zle -N _aicli_explain_widget
bindkey '^X' _aicli_explain_widget

# Feature 1: AI-Powered Inline Autosuggestion (using zle -F)

_AICLI_FD=0
_AICLI_LAST_BUFFER=""

# Async worker logic
_aicli_fetch_suggestion_worker() {
    local buffer="$1"
    local pwd="$2"

    # Debounce
    sleep "$AI_CLI_DEBOUNCE"

    local system_prompt="You are a Linux/macOS terminal expert. Complete the partial command intelligently, considering pwd and common flags. Output only the full suggested command line (no explanations). Current directory: $pwd"

    local suggestion=$(_aicli_call_llm "$buffer" "$system_prompt")

    if [[ -n "$suggestion" ]]; then
        echo "$suggestion"
    fi
}

# Handler for data on FD
_aicli_zle_handler() {
    local fd=$1
    local suggestion

    # Read all content from the file descriptor
    # Using cat <&$fd is reliable for pipes/substitutions
    suggestion=$(cat <&$fd)

    # Close FD in ZLE (stops watching)
    zle -F "$fd"
    exec {fd}<&-
    _AICLI_FD=0

    # Verify suggestion starts with BUFFER
    if [[ "$suggestion" == "$BUFFER"* ]]; then
            local suffix="${suggestion#$BUFFER}"
            if [[ -n "$suffix" ]]; then
                # Gray color for suggestion
                POSTDISPLAY=$'\x1b[90m'"$suffix"$'\x1b[0m'
                zle -R
            fi
    fi
}

# Trigger function
_aicli_trigger_autosuggest() {
    # Skip if buffer empty or same as last time
    if [[ -z "$BUFFER" ]] || [[ "$BUFFER" == "$_AICLI_LAST_BUFFER" ]]; then
        return
    fi
    _AICLI_LAST_BUFFER="$BUFFER"

    # Cancel previous async job if needed
    if [[ $_AICLI_FD -ne 0 ]]; then
        zle -F "$_AICLI_FD" # Stop watching
        exec {_AICLI_FD}<&- # Close
        _AICLI_FD=0
    fi

    # Clear current suggestion
    POSTDISPLAY=""

    # Start worker using process substitution
    # We silence stderr of the worker to avoid leaking errors to the prompt
    exec {_AICLI_FD}< <(_aicli_fetch_suggestion_worker "$BUFFER" "$PWD" 2>/dev/null)

    # Watch FD
    zle -F "$_AICLI_FD" _aicli_zle_handler
}

# Hook into ZLE non-destructively
autoload -Uz add-zle-hook-widget

# Hook `zle-line-pre-redraw`
_aicli_pre_redraw() {
    _aicli_trigger_autosuggest
}

if zle -N _aicli_pre_redraw; then
     add-zle-hook-widget zle-line-pre-redraw _aicli_pre_redraw
fi

# Accept suggestion
_aicli_accept_suggestion() {
    if [[ -n "$POSTDISPLAY" ]]; then
        local clean_suggestion
        # Use perl for portable ANSI stripping (handles macOS/Linux better than sed \x1b)
        if command -v perl >/dev/null 2>&1; then
            clean_suggestion=$(echo "$POSTDISPLAY" | perl -pe 's/\e\[[0-9;]*m//g')
        else
            # Fallback to sed with printf for portability
             clean_suggestion=$(echo "$POSTDISPLAY" | sed "s/$(printf '\033')\[[0-9;]*m//g")
        fi

        BUFFER="${BUFFER}${clean_suggestion}"
        POSTDISPLAY=""
        CURSOR=$#BUFFER
    else
        zle .forward-char
    fi
}
zle -N _aicli_accept_suggestion

# Bindings
bindkey '^[[C' _aicli_accept_suggestion
bindkey '^F' _aicli_accept_suggestion
