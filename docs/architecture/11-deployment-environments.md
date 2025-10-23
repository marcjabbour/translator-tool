# 11) Deployment & Environments

- **Infra**:  
  - Backend: Fly.io/Render/Railway (starter) → containerized on GKE/EKS (V3).  
  - DB: Supabase (managed Postgres, Auth, Storage).  
  - Caching: Redis (managed) if needed.

- **Envs**: `dev`, `staging`, `prod` with isolated projects & keys.  
- **CI/CD**: GitHub Actions  
  - Lint, type-check, unit tests, contract tests (Pydantic schemas), integration smoke tests.  
  - Tag and promote via `release/*` branches.

---
