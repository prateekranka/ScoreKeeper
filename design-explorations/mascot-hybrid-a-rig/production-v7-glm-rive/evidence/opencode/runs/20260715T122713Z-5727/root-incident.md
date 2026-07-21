# Root incident record

- Outcome: stopped before live mutation.
- Reason: the executor wrote `/tmp/verify-step1.mjs`, outside the authorized v7 local scope.
- Live preflight result: Rive MCP reachable; exact six protected artboards still present.
- Recovery: root terminated the owned OpenCode process, preserved `stdout.jsonl`, and tightened the brief to forbid all temporary/scratch paths outside `generated/`.
- The owned scratch helper was removed after its contents and hash were preserved in the run log and root tool evidence.
