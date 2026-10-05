# Automated Multi-Environment Deployment Pipeline

Commit → **CI (test, lint, secret scan, SAST, image scan)** → **dev → staging → production**, delivered with **GitOps (Argo CD)**, infrastructure from **Terraform** (VPC, EKS, RDS), with **approval-gated production promotion**, **automatic rollback** and **Prometheus/Grafana monitoring**.

![architecture](docs/architecture.md)  <!-- replace with an exported PNG of the Mermaid diagram -->

## Stack
GitHub Actions · Docker/GHCR · Terraform · AWS (VPC, EKS, RDS) · Kubernetes + Kustomize · Argo CD · Trivy · Gitleaks · SonarQube/SonarCloud · Checkov · Prometheus/Grafana/Alertmanager

## Repo layout
```
app/            Node.js REST API (+ /health /ready /metrics), multi-stage non-root Dockerfile, tests
.github/workflows/   ci, deploy-dev, deploy-staging, deploy-prod (approval), terraform
terraform/      bootstrap (state + OIDC), modules (vpc, eks, rds), envs/{dev,staging,prod}
k8s/            base + Kustomize overlays per environment
argocd/         AppProject + one Application per environment
monitoring/     PrometheusRule alerts, Alertmanager values, Grafana dashboard
scripts/        smoke-test.sh, local-kind.sh
docs/           architecture + runbook
```

## Pipeline flow
1. PR → CI: lint, unit tests, Gitleaks, (Sonar), Docker build, **Trivy fails on CRITICAL/HIGH**.
2. Merge to `develop` → image pushed as `:<sha>` → bot bumps `k8s/overlays/dev` → Argo CD syncs **dev**.
3. Merge to `main` → bot bumps `staging` overlay → Argo syncs → smoke test against `/health` verifying the deployed SHA.
4. Run **Deploy Production** → waits for a required reviewer → promotes the *same image* from staging → smoke test → on failure `git revert` rolls back automatically.

## Quick start

### Option A: local, free (kind)
```bash
make test lint
./scripts/local-kind.sh        # kind + Argo CD + kube-prometheus-stack
```

### Option B: AWS
1. `cd terraform/bootstrap && terraform init && terraform apply -var state_bucket=<unique> -var github_repo=<owner/repo>`
2. Put the bucket name in each `terraform/envs/*/main.tf` backend block; set repo variable `AWS_ROLE_ARN` to the `role_arn` output.
3. `cd terraform/envs/dev && terraform init && terraform apply -var-file=terraform.tfvars`
4. Install Argo CD + ingress-nginx + kube-prometheus-stack on each cluster, then `kubectl apply -f argocd/`.

### GitHub setup checklist
- Replace `OWNER` in `k8s/overlays/*/kustomization.yaml` and `argocd/*.yaml`.
- **Settings → Environments**: create `dev`, `staging`, `production` (add *Required reviewers* on `production`).
- **Variables**: `STAGING_URL`, `PROD_URL`, `AWS_ROLE_ARN`, optional `ENABLE_SONAR=true` (+ secrets `SONAR_TOKEN`, `SONAR_HOST_URL`).
- **Actions → Workflow permissions**: read & write (so deploy bots can commit).
- Branch protection on `main`/`develop`: require CI. Allow the bot to push (or switch the bot to open PRs).
- Make the GHCR package readable by the cluster (public, or add an imagePullSecret).

## Environment differences
| | dev | staging | prod |
|---|---|---|---|
| Replicas (HPA min–max) | 1–2 | 2–4 | 3–10 |
| EKS nodes | 1× t3.medium SPOT | 2× t3.medium | 3× t3.large |
| RDS | t4g.micro single-AZ | t4g.small single-AZ | t4g.medium **Multi-AZ**, deletion protection |
| NAT | single | single | single (switch `single_nat=false` for per-AZ HA) |
| Deploy trigger | auto | auto + smoke | manual approval + smoke + auto-revert |

## What this demonstrates
CI/CD · DevSecOps shift-left · IaC with reusable modules and remote state · GitOps · immutable artifacts (build once, deploy many) · least-privilege OIDC auth · observability and alerting · rollback strategy.

## Ideas to extend
Argo Rollouts canary · Slack deploy notifications · scheduled dev scale-down · OPA/Kyverno policies · DORA metrics dashboard · External Secrets Operator.
