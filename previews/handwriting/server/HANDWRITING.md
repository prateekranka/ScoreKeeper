# Handwriting sample collection

The private web preview provides `/handwriting`
Each anonymous writer gets a guided set of forty scores, starting with digits 0–9 and continuing with a shuffled mix of single and two-digit scores
A different person can select New writer on the same device
Existing writers and unsaved drafts remain available in the native writer selector
The browser keeps the current writer and raw draft separately from game data

Saving records the prompted score and advances in place
There is no recognition or extra confirmation screen during collection
Clear drawing and Undo last stroke edit the current draft
Undo last saved sample restores the previous drawing and marks its stored record as discarded
Discarded records remain recoverable in the database but are excluded from exports and counts
A writer can stop at any point and resume later

The server stores raw normalized strokes, timing, pressure when available, pointer type, viewport size, a rendered PNG and the known prompt label
Saved samples are in `.runtime/handwriting/samples.sqlite3`
The directory is private to the Mac user and samples are committed atomically in SQLite
A sample UUID makes retries idempotent
The same prompt cannot be saved twice for the same writer
Outdated prompts cannot silently relabel a drawing
Request origin and CSRF checks protect mutations
Collection makes no Jev or other model requests

Download samples returns a ZIP snapshot with labelled images, raw stroke JSON, a manifest and collection provenance
The export is built with bounded memory and excludes credentials and game data
Labels are contributor confirmations of prompts and still need review
New samples are marked unreviewed and reserved for a future holdout set
They are not automatically counted as independent validation data
Before evaluation, review labels and actual writer participation, freeze a dataset version, and keep a separate holdout from any samples used to tune recognition
The anonymous writer identifiers do not verify personal identity

The environment variable `PIPCOUNT_HANDWRITING_DIR` can select a separate task-owned collection store
QA runs use a separate evidence directory, so automated drawings do not enter the real handwriting corpus
Shared-link checks are read only for the collection

TesterArmy scenarios cover saves, advance, Undo, per-writer drafts, reload, rotation, service-token refresh, lost responses, concurrent retries, stale tabs, malformed input, request protection and ZIP contents
Existing score-entry checks cover the reused writing canvas
