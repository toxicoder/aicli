# aicli (zsh)

**Simple AI integrations (i.e. auto complete) intended to be used with small local LLMs.**

This zsh plugin provides lightweight, privacy-focused AI assistance in the terminal, optimized for small local LLMs (primarily via **Ollama**, with easy extension to other local servers like LM Studio or llama.cpp). It targets power users on **Linux** (primary) and **macOS** who know what they want to achieve but frequently forget exact commands, flags, or syntax—reducing time spent googling or man-page hunting.

The plugin is deliberately minimal: no agent-like execution, no complex context tracking beyond what's needed for suggestions. It focuses on seamless integration with zsh's native features (building on/inspired by `zsh-autosuggestions` for styling).

## Dependencies
- Ollama (for local LLM serving; default endpoint `http://localhost:11434`)
- `curl` and `jq` (common on Linux/macOS for API calls)
- Optional: `fzf` for interactive selection in chat mode

## Installation (Oh My Zsh example)
```zsh
git clone https://github.com/toxicoder/aicli.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/aicli
```

Add to `~/.zshrc`:
```zsh
plugins+=(aicli)
```

Recommended configuration in `~/.zshrc`:
```zsh
export AI_CLI_MODEL="qwen2.5-coder:7b"  # See model recommendations below
export AI_CLI_ENDPOINT="http://localhost:11434/api/chat"  # Ollama default
```

Then reload: `source ~/.zshrc`

## Features
The plugin keeps a **small, focused feature set** (three core features) to super-power terminal workflows without overhead.

### 1. AI-Powered Inline Autosuggestion
The primary feature: As you type a command, the plugin asynchronously queries the local LLM for a context-aware completion suggestion.

- **How it works**: On buffer change (after a short debounce, e.g., 500ms idle), it sends the current line, current directory (`pwd`), and recent history snippet to the LLM with a prompt like:  
  *"You are a Linux/macOS terminal expert. Complete the partial command intelligently, considering pwd and common flags. Output only the full suggested command line (no explanations)."*
- **UX**: The suggestion appears inline after the cursor in a **lighter/dimmed font style** (using `zsh-autosuggestions`-compatible highlighting, default `fg=8` or `fg=#888888` for gray/dim). This visually indicates it's an AI suggestion, not typed text.
  - Accept fully: Right arrow (→) or custom binding (e.g., Ctrl+E).
  - Partial accept: Forward-word (common in zsh).
  - Clear: Ctrl+U or continue typing.
- **Fallback**: If no AI suggestion (timeout or empty), falls back to history-based suggestions (integrates with existing `zsh-autosuggestions` if installed).
- **Performance**: Tuned for small models (e.g., 3B-7B params); suggestions in <1-2s on modern hardware. Configurable timeout/throttle to avoid lag.
- **Why it super-powers**: Instantly recalls forgotten flags/syntax (e.g., typing `tar -` → suggests `-czf archive.tar.gz files/`) without breaking flow.

### 2. Quick Chat Query
An easy, non-intrusive way to ask the LLM a question in "chat" style for command help or explanations.

- **How it works**: Prefix your line with `?` (or custom prefix, e.g., `ai?`) and press Enter.
  - Example: `? how to find large files in current dir modified last week`
  - The plugin sends the query (plus optional context: pwd, recent history) to the LLM with a prompt like:  
    *"You are a concise terminal expert. Provide the exact command(s) for: [query]. Include brief flag explanations if helpful. Output only commands and short notes—no chit-chat."*
- **UX**: Response prints directly in the terminal (streamed if possible). The original `?` line is cleared/replaced. No execution—just copy-paste or edit the output.
  - Optional: If `fzf` installed, multi-line responses show in fzf preview for selection.
- **Why it super-powers**: Quick lookup for complex commands (e.g., `ffmpeg` flags, `find` expressions) without leaving the terminal or searching online.

### 3. Command Explanation
A lightweight helper to explain the command you're about to run.

- **How it works**: Select a line (or current buffer) and trigger via keybinding (default: Ctrl+X).
  - Sends the command to the LLM: *"Explain this command briefly, including what each flag does. Be concise."*
- **UX**: Explanation prints above the command line (non-destructive). Useful for sanity-checking recalled syntax.
- **Why it super-powers**: Reinforces learning—helps memorize flags over time while preventing mistakes.

## Suggested Models
The plugin works best with small, fast models that excel at instruction-following and code/shell tasks. Use instruct-tuned variants for deterministic command output.

Here are ranked recommendations (as of December 2025) based on speed, accuracy for shell command generation/completion, and hardware fit (prioritizing <10B params for low latency):

| Rank | Model Tag (Ollama)              | Params | Strengths                                      | Approx. RAM (Q4/Q5 quant) | Best For                          | Pull Command                          |
|------|---------------------------------|--------|------------------------------------------------|-----------------------------------|-----------------------------------|---------------------------------------|
| 1    | qwen2.5-coder:7b                | 7B    | Excellent shell/code reasoning, concise output | ~6-8GB                           | Balanced speed & accuracy         | `ollama pull qwen2.5-coder:7b`       |
| 2    | deepseek-coder:7b               | 7B    | Strong code/shell generation, fast inference  | ~6-8GB                           | Coding-heavy workflows            | `ollama pull deepseek-coder:7b`      |
| 3    | llama3.2:3b                     | 3B    | Very fast, good for basic commands            | ~4-5GB                           | Low-end hardware / max speed      | `ollama pull llama3.2:3b`            |
| 4    | phi-3:mini (or phi-3.5:mini)    | 3.8B  | Efficient, strong reasoning on small size     | ~4GB                             | CPU-only or limited RAM           | `ollama pull phi3:mini`              |
| 5    | codegemma:7b                    | 7B    | Good completion, Google-backed                | ~6-8GB                           | Alternative to Qwen               | `ollama pull codegemma:7b`           |
| 6    | mistral:7b-instruct             | 7B    | Reliable generalist, fast                     | ~6GB                             | If specialized models unavailable | `ollama pull mistral:7b-instruct`    |

- Start with **qwen2.5-coder:7b** for the best mix of quality and speed.
- Use quantized tags (e.g., `:q4_K_M`) for lower memory if needed.
- Larger models (e.g., 34B+) provide higher accuracy but slower suggestions—avoid for autosuggest.

## Additional Notes
- **Privacy/Speed**: Everything local—no cloud APIs by default.
- **Configurability**: Variables for model, temperature (set low ~0.3 for deterministic commands), context size, and keybindings.
- **Compatibility**: Tested on Linux (Ubuntu/Fedora) and macOS; avoids heavy dependencies.
- **Extensibility**: Easy to add support for other local backends (e.g., OpenAI-compatible servers).
