# Repeated-timeout recovery

Two 1800-second GLM runs ended before authoring or live mutation. The second used
a 97-line narrow brief and still spent the remaining turn in model generation.

Primary-source options considered:

1. Deny `task` so subagents disappear from the tool description. OpenCode agents
   documentation: https://opencode.ai/docs/agents/
2. Explicitly select the built-in Build primary agent with `--agent build`.
   OpenCode CLI and agents documentation: https://opencode.ai/docs/cli/ and
   https://opencode.ai/docs/agents/
3. Use CLI `--pure` to run without external plugins. Confirmed by local
   `opencode run --help` for installed OpenCode 1.17.11.
4. Set `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1` and
   `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` to suppress compatibility context.
   OpenCode rules documentation: https://opencode.ai/docs/rules
5. Split implementation into one-artifact passes and attach only the narrow file
   needed for each pass. OpenCode CLI supports explicit files, agents, model,
   variant, and independent sessions: https://opencode.ai/docs/cli/

Chosen recovery: preserve exact `opencode-go/glm-5.2` + `max` + JSON route; run
fresh sessions with `--pure --agent build`, disable Claude compatibility prompt
and skills only for the child process, and reduce the next pass to motion spec
authorship with no live access. No repository/global OpenCode config is changed.
