# Runbook

## Roll back production
- Automatic: `deploy-prod` reverts its own commit if the smoke test fails.
- Manual (Git): `git revert <deploy(prod) commit> && git push` and Argo CD syncs the previous tag.
- Emergency (cluster): `kubectl -n app-prod rollout undo deploy/app` (Argo `selfHeal` will undo this unless you pause auto-sync: `argocd app set app-prod --sync-policy none`).

## Database credentials
RDS creates the master password in AWS Secrets Manager (`terraform output db_secret_arn`).
Sync into the cluster with External Secrets Operator or Sealed Secrets as `db-credentials` (key `url`) in each `app-<env>` namespace. The Deployment reads it via `secretKeyRef` (optional, so the app falls back to in-memory storage without it).

## Database migrations
Run migrations as a Helm/Argo `PreSync` Job using expand-contract (backward-compatible) changes, so rolling updates and rollbacks stay safe.

## Alerts
| Alert | First step |
|---|---|
| AppDown | `kubectl -n app-<env> get pods; kubectl logs deploy/app` |
| HighErrorRate | Check Grafana "Golden Signals"; compare to last deploy time; roll back if correlated |
| HighLatencyP95 | Check HPA, DB connections, CPU throttling |
| PodCrashLooping | `kubectl describe pod`; look for OOMKilled and raise limits in the overlay |

## Cost control
`terraform destroy` dev/staging when idle. Dev uses SPOT nodes and a single NAT gateway.
