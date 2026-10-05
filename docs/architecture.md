# Architecture

```mermaid
flowchart LR
  Dev[Developer] -->|PR| GH[GitHub]
  GH --> CI[CI: lint, test, Gitleaks, Sonar]
  CI --> Build[Docker build]
  Build --> Trivy{Trivy scan}
  Trivy -->|pass| GHCR[(GHCR image :sha)]
  Trivy -->|fail| Stop[Pipeline blocked]
  GHCR --> DevWF[deploy-dev on develop]
  GHCR --> StgWF[deploy-staging on main]
  DevWF -->|bump tag| Git[(Git: k8s overlays)]
  StgWF -->|bump tag| Git
  Approve[[Manual approval: production env]] --> ProdWF[deploy-prod same image]
  ProdWF -->|bump tag| Git
  Git -->|watch| Argo[Argo CD]
  Argo --> DevC[app-dev]
  Argo --> StgC[app-staging]
  Argo --> ProdC[app-prod]
  ProdWF -->|smoke fails| Revert[git revert -> auto rollback]
  DevC & StgC & ProdC --> Prom[Prometheus] --> Graf[Grafana]
  Prom --> AM[Alertmanager -> Slack]
  TF[Terraform: VPC, EKS, RDS] -.provisions.-> DevC & StgC & ProdC
```

## Key design decisions
| Decision | Why |
|---|---|
| Build once, promote the SHA-tagged image | What was tested in staging is byte-for-byte what runs in prod |
| GitOps with Argo CD (pull) | Git is the audit log; cluster creds never leave the cluster; `selfHeal` reverts drift |
| CI does not touch the cluster | CI only needs to write to Git and GHCR |
| Kustomize overlays | Per-env replicas, limits, host, image tag with no templating |
| OIDC to AWS | No long-lived keys in GitHub |
| RDS `manage_master_user_password` | DB password lives in Secrets Manager, never in Terraform state or Git |
| Rollback = `git revert` | Same path as deploy; fully audited |
| Remote state S3 + DynamoDB lock | Safe concurrent runs, versioned state |

## Branch / environment mapping
| Branch | Environment | Gate |
|---|---|---|
| `develop` | dev | CI green |
| `main` | staging | CI green + smoke test |
| `main` (manual `Deploy Production` run) | prod | Required reviewers + smoke test + auto-revert |
