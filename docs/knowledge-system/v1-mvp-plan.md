# AKA V1: MVP Implementation Strategy

Building the "right" MVP for the Agentic Knowledge Architecture (AKA) means focusing on the **Cognitive Discipline** rather than perfect infrastructure. A V1 should prove that an agent can be constrained and guided to maintain knowledge integrity.

---

## 1. The "Thin Vertical Slice" Approach

Instead of building a global system, we implement the full stack for a **single domain** (e.g., the `Runbooks` folder).

### V1 Scope:
- **Domain**: `docs/knowledge-system/runbooks/`
- **Capabilities**: Search, Read, and "Smart Merge" update.
- **Goal**: Demonstrate an agent fixing an outdated runbook without breaking structure or duplicating info.

---

## 2. V1 Tech Stack (The "Good Enough" PoC)

| Component | V1 Solution | Why? |
| :--- | :--- | :--- |
| **Search Substrate** | **MeiliSearch Only** | Skip vectors for V1. Keyword/Prefix search is 100% reliable for navigation and basic discovery. |
| **Orchestration** | **Simple Python Loop** | Skip LangGraph. A while-loop with explicit "Circle" checks in code is faster to iterate on for PoC. |
| **Storage** | **Local Filesystem** | No Git sync yet. Just read/write to local `.md` files. |
| **Enforcement** | **Hardcoded System Prompt** | No dynamic trust DB. Put the Circle Model and Smart Merge rules directly in the system prompt. |

---

## 3. The MVP Execution Plan (The "Right Way")

### Step 1: The "Navigation Substrate"
Create a script (`v1_indexer.py`) that:
1. Scans the target folder.
2. Extracts YAML frontmatter.
3. Automatically generates an `_index.md` file if it doesn't exist.
4. Populates MeiliSearch with both document content AND the index metadata.

### Step 2: The "Circle" Search Tool
Implement a search tool that takes a `depth` parameter:
- `depth=1`: Returns ONLY index files (Circle 1).
- `depth=2`: Returns document metadata/headers (Circle 2).
- `depth=3`: Returns full content chunks (Circle 3).
**The agent is instructed to start at `depth=1`.**

### Step 3: The "Merge" Write Tool
Replace `write_file` with `merge_kb_file(path, new_content)`:
1. **Force Read**: The tool automatically reads the current file first.
2. **LLM Diff**: Calls a small, cheap model (e.g., GPT-4o-mini) to perform the merge according to the "Smart Merge" prompt.
3. **Review**: Print the diff to the console for the human developer to approve.

### Step 4: The "Protocol" Prompt
Use a system prompt that enforces behavior:
```text
"You are a Knowledge Librarian. You must follow these constraints:
1. ORIENT FIRST: Never search for details without reading the folder _index.md first.
2. INTEGRATE, DON'T APPEND: When updating, modify existing sentences. Do not add 'Update:' notes.
3. AUDIT: Always add a single line to the '# Progress Log' at the bottom of the file."
```

---

## 4. Success Criteria for MVP
- [ ] Agent correctly identifies an outdated runbook by starting at the root index.
- [ ] Agent updates the existing content rather than appending a new section.
- [ ] Agent adds a valid entry to the Progress Log.
- [ ] The entire process takes < 30 seconds and uses < $0.05 in tokens.

---

## 5. Moving to V2 (Post-MVP)
- **Add Vector Search**: Integrate Qdrant for semantic "Discovery Mode."
- **Add Trust Gradient**: Move the hardcoded prompt into a dynamic score-based middleware.
- **Add Git Integration**: Automatically commit and push changes with the audit trail.
