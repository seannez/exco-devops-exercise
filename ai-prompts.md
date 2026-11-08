# AI Assistance and Prompt Log — EX.CO DevOps Exercise

**Date:** 2026-11-08  
**AI assistant:** ChatGPT  
**Repository:** https://github.com/seannez/exco-devops-exercise

## Important note on accuracy

This file reconstructs the **substance and chronological topics** of prompts sent to ChatGPT during development. The entries below are **not presented as verbatim quotations** from the original chat. Exact individual prompt text was not available for export while preparing this file. The original ChatGPT session should be kept available for review of literal prompts and responses, as required by the exercise. Commands, problems, and outcomes described below were checked against the development session and repository.

## Reconstructed prompt requests

### 1. Assignment plan and tool selection

**Reconstructed request:** Help break down the EX.CO DevOps technical assignment into a fast, practical sequence: small web app, Docker, Terraform-managed Kind cluster with one control-plane and two workers, Helm-installed Argo CD and an ingress controller, GitOps manifests, and CI/CD if time allows. Prefer short commands and ready-to-use configuration over long explanations.

**Outcome:** Implemented the work in the order above and created an initial repository plan.

### 2. Minimal web application

**Reconstructed request:** Create a minimal Node.js HTTP service without unnecessary dependencies. `GET /` must serve actual HTML containing a message, the application version, and the serving pod name. `GET /healthz` must return HTTP 200.

**Outcome:** Created `app.js` and `package.json`, using `process.env.HOSTNAME` to identify the pod.

### 3. Non-root Docker image and local verification

**Reconstructed request:** Provide a simple Dockerfile that builds and runs the application as a non-root user, and show how to test the root and health endpoints locally.

**Outcome:** Created `Dockerfile` using `node:22-alpine` and `USER node`; tested the Docker image and HTTP endpoints locally.

### 4. Terraform and a three-node local Kubernetes cluster

**Reconstructed request:** Use Terraform to create a Kind Kubernetes cluster with exactly one control-plane and two workers. Configure a host port so the application can eventually be reached in a browser, and install Argo CD and an ingress controller through Helm.

**Outcome:** Created `terraform/main.tf` with the Kind provider, Argo CD Helm release, and Traefik Helm release. The cluster exposes HTTP through port `8088` on the host.

### 5. Argo CD Helm download failure

**Reconstructed request:** The Argo CD Helm chart download is returning HTTP 504 on the current network. Diagnose the download issue and suggest a reliable chart source without changing the deployment goal.

**Outcome:** Switched the Argo CD chart source to `oci://ghcr.io/argoproj/argo-helm`; the Helm installation subsequently succeeded.

### 6. Traefik routing and port mapping

**Reconstructed request:** Configure Traefik for a local Kind cluster with NodePort `30080`, reachable at `http://localhost:8088/` through the control-plane port mapping, and explain how the Ingress routes to the Node.js application.

**Outcome:** Added Traefik Helm values and a Kubernetes Ingress using `ingressClassName: traefik`.

### 7. Local Docker image not initially available to Kind

**Reconstructed request:** The application image is built in Docker but is not available in the Kind worker nodes. Installing the Kind CLI is failing. How can the image be imported into the nodes with available Docker/containerd tools?

**Outcome:** Manually imported the development image into worker-node containerd. An initial AI-suggested `/tmp` archive path did not work; inspecting the failure and copying to `/root/exco-app.tar` resolved it. Later, the final GitOps deployment switched to a public GHCR image, removing the need for local imports.

### 8. Kubernetes Deployment, Service, and probes

**Reconstructed request:** Write the Kubernetes manifests for two application replicas, `/healthz` readiness and liveness checks, CPU and memory requests/limits, and a ClusterIP Service that forwards from port 80 to the container's port 3000.

**Outcome:** Created `manifests/deployment.yaml` and `manifests/service.yaml` and confirmed both pods reached Ready status.

### 9. Ingress and Argo CD GitOps setup

**Reconstructed request:** Create an Ingress for `http://localhost:8088/` and an Argo CD Application watching the `manifests` folder on the repository's `main` branch, with automated synchronization, pruning, and self-healing.

**Outcome:** Created `manifests/ingress.yaml` and `application.yaml`; bootstrapped Argo CD with `kubectl apply -f application.yaml`.

### 10. Argo CD Ingress health

**Reconstructed request:** Kubernetes is serving the application, but Argo CD still shows the Ingress as `Progressing`. Investigate why a local Traefik Ingress does not have the expected published address.

**Outcome:** Configured Traefik's ingress endpoint hostname as `localhost` and disabled published-Service address discovery. Argo CD subsequently showed `Synced` / `Healthy`.

### 11. GitHub Actions build and publish

**Reconstructed request:** Add GitHub Actions so each push to `main` builds the non-root Docker image and pushes it to GitHub Container Registry with the source commit SHA as the tag, using the workflow's `GITHUB_TOKEN`.

**Outcome:** Created `.github/workflows/ci.yml` and published the image to GHCR. Configured the package to allow public pulls by Kubernetes.

### 12. Automatic GitOps image updates

**Reconstructed request:** Extend the workflow so it changes the `image:` value in `manifests/deployment.yaml`, commits and pushes that change to `main`, and lets Argo CD perform the deployment. Do not deploy directly from CI with `kubectl apply`.

**Outcome:** Added the manifest-update commit step, with Git write permission for the workflow. The pipeline ultimately published SHA-tagged images and updated the Git manifest automatically.

### 13. CI workflow and permissions troubleshooting

**Reconstructed request:** GitHub Actions is not triggering as expected, and/or the image-update step is not changing the committed manifest. Check the workflow file location, repository permissions, and Git command behavior.

**Outcome:** Corrected the workflow location under `.github/workflows/`, corrected Git permissions and the image-line replacement, and verified successful Actions runs.

### 14. Application update and rollout verification

**Reconstructed request:** Change the page message and bump the application version, push the change, then verify GitHub Actions, the container registry image, Argo CD synchronization, replacement pods, and the HTTP response.

**Outcome:** Published a build from source commit `8268a780b57623680f8ac6e90f021151b22ec6c7`. The application ultimately returned `Hello from EX.CO version 2!` and `App version: 1.0.1` through the Ingress.

### 15. Zero-downtime check and computer interruption

**Reconstructed request:** Help verify whether HTTP requests fail during rollout. After a local computer crash during a repeated-request test, avoid another resource-heavy loop and focus on confirming deployment health.

**Outcome:** Did **not** claim a zero-downtime result because the measurement was interrupted; confirmed the final version, healthy pods, and working endpoint instead.

### 16. Git repair after the crash

**Reconstructed request:** The local repository has a corrupt `refs/heads/main`, Git reports no commits, fetch fails with `fatal: bad object refs/heads/main`, and pushes are rejected as non-fast-forward. Recover the local work and upload the new version safely without force-pushing or losing GitHub Actions commits.

**Outcome:** Preserved the work in `recovery-exco`, backed up and removed the broken local reference, fetched the latest GitHub `main`, rebased, and pushed the updated application source. No history rewrite was needed on the remote repository.

### 17. Kubernetes recovery after Docker Desktop restart

**Reconstructed request:** Docker Desktop was off during the push. After starting it, `kubectl` cannot connect to `127.0.0.1:<port>`. Compare the forwarded API-server port with kubeconfig and check the API server without deleting the cluster.

**Outcome:** Confirmed the port mapping and kubeconfig matched; after startup, the API server was running and all three nodes were `Ready`.

### 18. Why the old page was initially returned

**Reconstructed request:** Argo CD says `Synced` / `Healthy` and the Deployment points to the latest GHCR tag, but `curl` still returns version `1.0.0`. Inspect pods, actual image references, and source inside the container.

**Outcome:** The new pods were eventually running the new image. Inspecting `/app/app.js` confirmed version `1.0.1`, and a new HTTP request returned the updated page. This was consistent with a rollout still in progress during the earlier request.

### 19. Final documentation

**Reconstructed request:** Write `README.md` and `ai-prompts.md`, prioritizing instructions that allow reviewers to reproduce the project on a fresh machine. Include relevant failures, workarounds, completed and missing requirements, design decisions, and a concrete AI error that was detected and corrected.

**Outcome:** Created these documentation files, including tested commands, clean-install guidance, platform limitations, and an explicit account of what was not verified.

## How AI output was verified

- Built and ran the app locally; checked `GET /` and `GET /healthz`.
- Verified the cluster using `kubectl get nodes` (one control-plane and two workers).
- Verified Argo CD application state (`Synced`, `Healthy`) and two Ready application pods.
- Checked the GitHub Actions result, Git image-tag commit, Deployment image, and image contents inside the container.
- Verified the public endpoint returned the updated HTML version `1.0.1`.
- Rejected or corrected AI suggestions when actual command errors or status output contradicted them (notably the early manual image-import path).

**Scope:** This log records AI-assisted requests and their outcomes; it is not an assertion that every prompt is reproduced word-for-word. The original ChatGPT conversation remains the authoritative verbatim record.
