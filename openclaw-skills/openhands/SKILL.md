---
name: openhands
description: Dispatch coding, refactoring, and repo-level tasks to a self-hosted OpenHands AI agent instance.
version: 1.0.0
metadata:
  openclaw:
    requires:
      bins:
        - curl
        - jq
    envVars:
      - name: OPENHANDS_URL
        required: false
        description: Base URL of the OpenHands instance (e.g. http://openhands-app:3000 or http://host.docker.internal:3000). Default is http://openhands-app:3000.
      - name: OPENHANDS_API_KEY
        required: false
        description: Optional API Key if OpenHands authentication is enabled.
    emoji: "🙌"
    homepage: https://github.com/OpenHands/OpenHands
---

# OpenHands Integration Skill for OpenClaw

Teach the agent how to delegate coding, debugging, refactoring, and bash-heavy software engineering tasks to a local or remote **OpenHands** instance.

## When to use this skill
- When the user asks to write complex code, refactor a repository, add tests, or fix a bug in a codebase.
- When an operation requires full terminal/sandbox execution that is better handled by OpenHands' specialized CodeAct agent.
- When you want to trigger automated coding tasks asynchronously.

## Configuration
- `OPENHANDS_URL`: The URL to reach OpenHands.
  - Same Docker Network: `http://openhands-app:3000`
  - From Docker to Host: `http://host.docker.internal:3000`
  - Default fallback: `http://openhands-app:3000`

---

## Workflow & Operations

### 1. Health Check
Check whether OpenHands is online and responsive before dispatching tasks:

```bash
curl -s -f "${OPENHANDS_URL:-http://openhands-app:3000}/api/options" > /dev/null && echo "ONLINE" || echo "OFFLINE"
```

### 2. Dispatch a Coding Task (Start Conversation)
Send a new prompt/task to OpenHands via the REST API:

```bash
OPENHANDS_URL="${OPENHANDS_URL:-http://openhands-app:3000}"

# Create conversation task
RESPONSE=$(curl -s -X POST "${OPENHANDS_URL}/api/v1/app-conversations" \
  -H "Content-Type: application/json" \
  -d '{
    "initial_message": {
      "role": "user",
      "content": [{"type": "text", "text": "请分析当前仓库代码，并在 tests/ 目录下添加对应的单元测试用例。"}],
      "run": true
    }
  }')

echo "$RESPONSE"
CONVERSATION_ID=$(echo "$RESPONSE" | jq -r '.app_conversation_id // .id // empty')
echo "Created Conversation: $CONVERSATION_ID"
```

### 3. Check Task Status
Poll the conversation status until the agent finishes:

```bash
OPENHANDS_URL="${OPENHANDS_URL:-http://openhands-app:3000}"
CONVERSATION_ID="<your_conversation_id>"

curl -s "${OPENHANDS_URL}/api/v1/app-conversations/${CONVERSATION_ID}" | jq '{status: .status, title: .title}'
```

### 4. Fetch Results and Execution Logs
Retrieve recent events or changes produced by OpenHands:

```bash
OPENHANDS_URL="${OPENHANDS_URL:-http://openhands-app:3000}"
CONVERSATION_ID="<your_conversation_id>"

curl -s "${OPENHANDS_URL}/api/v1/conversation/${CONVERSATION_ID}/events/search" | jq '.events[-5:]'
```

---

## Instructions for OpenClaw Agent
1. **Analyze the Request**: Identify if the user's intent is a complex multi-file engineering task.
2. **Pre-check**: Verify `OPENHANDS_URL` connectivity.
3. **Format Task Prompt**: Provide a crystal-clear prompt containing:
   - Target goal and scope
   - Relevant file paths inside the mounted `/workspace`
   - Acceptance criteria and verification commands
4. **Delegate**: Call the OpenHands API and return the conversation ID or status to the user.
