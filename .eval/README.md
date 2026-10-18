# Eval reference material

`fixer/<task>/reference/**` holds the regression tests the maintainers' own fix for that
issue shipped with, mirrored at their repository paths, and `files.txt` lists the ones a
CPU-only runner can execute. `.github/workflows/eval-ci.yml` copies them over the PR head
before running them, so an eval fixer cannot pass by editing expected outputs. The source
of truth is `slang-coworkers/slang-eval-tasks`, `tasks/fixer/*`; regenerate this directory
from that bank when it changes.
