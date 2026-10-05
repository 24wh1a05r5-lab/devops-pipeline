.PHONY: install test lint run docker kind-up kind-deploy kustomize-check
install:; cd app && npm ci
test:; cd app && npm test
lint:; cd app && npm run lint
run:; cd app && npm start
docker:; docker build -t devops-demo-api:local app
kustomize-check:; for e in dev staging prod; do kubectl kustomize k8s/overlays/$$e >/dev/null && echo "$$e OK"; done
kind-up:; ./scripts/local-kind.sh
kind-deploy:; kubectl apply -k k8s/overlays/dev
