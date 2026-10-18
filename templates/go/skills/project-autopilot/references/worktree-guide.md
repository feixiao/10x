# Git Worktree 隔离实操指南 (Go)

```bash
git worktree add -b feat/<topic-name> ../worktrees/<topic-name> origin/main
cd ../worktrees/<topic-name>
bash scripts/setup-ai-env.sh
```
