# EX.CO DevOps Technical Exercise

A small Node.js service deployed to a local Kubernetes cluster using Terraform, Helm, Argo CD, and GitHub Actions. The repository is the source of truth for the Kubernetes manifests; CI builds an immutable container image and commits its new tag to Git, and Argo CD performs the deployment.

**Repository:** https://github.com/seannez/exco-devops-exercise  
**Tested environment:** Windows 11, Docker Desktop (Linux containers, x86-64), PowerShell, local Kind cluster.  
**Application:** http://localhost:8088/  
**Health endpoint:** http://localhost:8088/healthz

## What was completed

| Requirement | Result |
| --- | --- |
| Small web service: HTML at `/`, HTTP 200 at `/healthz` | Completed; currently displays version `1.0.1` and the serving pod name |
| Docker image runs as non-root | Completed (`USER node` on `node:22-alpine`); built and tested locally |
| Terraform-managed Kind cluster with 1 control-plane + 2 workers | Completed; all 3 nodes verified `Ready` |
| Argo CD and ingress controller installed by Terraform/Helm | Completed; Argo CD and Traefik running |
| GitOps deployment from manifests in this repository | Completed; Argo CD reported `Synced` / `Healthy` |
| 2 replicas, readiness/liveness, CPU/memory requests and limits | Completed; both pods verified `1/1 Running` |
| Browser access via Kubernetes Ingress | Completed; verified through `http://localhost:8088/` |
| GitHub Actions builds and publishes a commit-SHA-tagged image to GHCR | Completed; workflow succeeded |
| CI commits the image update to Git; Argo CD rolls it out | Completed; a code change reached the running pods |
| **Zero-downtime proof during rollout** | **Not verified**; a request-loop test was interrupted by a local computer crash |
| HPA (2–5), Prometheus, Grafana | Not implemented |
| Discussion of production EKS changes | Included below |

**Last verified deployment:** application version `1.0.1`, message `Hello from EX.CO version 2!`, image `ghcr.io/seannez/exco-devops-exercise:8268a780b57623680f8ac6e90f021151b22ec6c7`. The last successful response also included the actual pod name, confirming which replica served the request. The image tag will change on future code pushes.

## Architecture

```text
Developer pushes code to main
          |
          v
GitHub Actions (.github/workflows/ci.yml)
          |-- Build Docker image
          |-- Push to GHCR, tagged with source commit SHA
          `-- Commit updated image: field to manifests/deployment.yaml
                                             |
                                             v
                                      Argo CD watches main/manifests
                                             |
                                             v
                                      Kubernetes Deployment (2 pods)

Browser -> localhost:8088 -> Kind control-plane host port mapping
        -> Traefik NodePort 30080 -> Ingress -> ClusterIP Service :80
        -> Node.js pods :3000
```

Terraform provisions the Kind cluster and installs **Argo CD** and **Traefik** using Helm. The root-level `application.yaml` is applied **once** to bootstrap Argo CD; after that, Argo CD continuously reconciles the resources under `manifests/`.

## Repository layout

```text
.
├── app.js                      # GET / and GET /healthz
├── package.json                # npm start
├── Dockerfile                  # non-root Node.js container
├── application.yaml            # bootstrap Argo CD Application
├── manifests/
│   ├── deployment.yaml         # 2 replicas, probes, resources, GHCR image
│   ├── service.yaml            # ClusterIP: 80 -> 3000
│   └── ingress.yaml            # Traefik ingress at /
├── terraform/
│   └── main.tf                 # Kind + Argo CD + Traefik Helm releases
├── .github/workflows/ci.yml   # build, publish, commit image tag
├── ai-prompts.md               # AI-assistance / troubleshooting log
└── README.md
```

## Prerequisites

Install and make available on your PATH:

- **Docker Desktop** (or a working Docker Engine), started and using Linux containers. Allocate enough resources to run **three Kubernetes nodes**, Argo CD, and Traefik; approximately 6–8 GB of available RAM is helpful.
- **Terraform**, **kubectl**, and **Git**.
- Internet connectivity to Terraform registries, Helm charts, GitHub, GHCR, and the Kind Kubernetes node image.
- **Node.js 22** only if you want to run the service outside Docker.

A separate `kind` executable is **not required** for provisioning: Terraform uses the `tehcyx/kind` provider. The Terraform configuration pins that provider to `0.11.0`, the Helm provider to `~> 3.2`, and the Argo CD Helm chart to `10.15.0`. Terraform downloads its providers during `init`.

> **Platform note:** The project was tested on an x86-64 Windows machine. The current GitHub Actions build is intended for the default Linux GitHub-hosted runner architecture (AMD64). **Apple Silicon / ARM64 reviewers should read the ARM64 note under Troubleshooting before deployment**; the existing image is not claimed to be multi-architecture.

## Reproduce from a fresh checkout

Commands below work in PowerShell; the Terraform, Git, and kubectl commands are also the same in a macOS/Linux terminal (`curl.exe` should be replaced by `curl` on macOS/Linux).

### 1. Clone the repository and check Docker

```powershell
git clone https://github.com/seannez/exco-devops-exercise.git
cd exco-devops-exercise
docker info
terraform version
kubectl version --client
```

Make sure Docker Desktop is fully running **before** provisioning the cluster. The example below assumes host port **8088** is free.

### 2. Initialize Terraform

```powershell
terraform -chdir=terraform init
```

Terraform manages the cluster, Argo CD, and Traefik in one configuration. On a **clean machine**, the Helm provider is configured to use the Kubernetes context `kind-exco`, which does not exist until Kind has created the cluster. For reliable first-time bootstrap, apply the cluster resource first, then the complete configuration:

```powershell
terraform -chdir=terraform apply -target=kind_cluster.exco
kubectl config use-context kind-exco
kubectl get nodes
terraform -chdir=terraform apply
```

Approve the two Terraform plans when prompted. The targeted apply is a **bootstrap workaround**, not a normal practice for ongoing changes; subsequent updates use ordinary `terraform apply`. The first command should create the **1 control-plane and 2 workers**, and the second installs **Argo CD** and **Traefik**.

Expected nodes (names are fixed; exact ages and versions can differ):

```text
exco-control-plane   Ready   control-plane
exco-worker          Ready   <none>
exco-worker2         Ready   <none>
```

Verify the installed components:

```powershell
kubectl get pods -n argocd
kubectl get pods -n traefik
kubectl get ingressclass
kubectl get svc -n traefik
```

Traefik should have a NodePort service with HTTP mapped to **30080**, which Kind maps to **localhost:8088**. The same Terraform file maps HTTPS **30443** to host **8443**, but this exercise does **not** configure a TLS certificate or require HTTPS.

### 3. Bootstrap the Argo CD Application

From the **repository root**:

```powershell
kubectl apply -f application.yaml
kubectl get applications -n argocd
kubectl get pods -n exco-app
kubectl get ingress -n exco-app
```

Argo CD reads `manifests/` from the public GitHub repository's `main` branch and automatically creates the `exco-app` namespace (`CreateNamespace=true`). Allow initial provisioning and image pulling to finish; then check the status again. Expected final state:

```text
NAME       SYNC STATUS   HEALTH STATUS
exco-app   Synced        Healthy
```

There should be **two Ready application pods**. The Deployment references an existing, **public GHCR image** tagged with a source commit SHA, so a reviewer on a compatible AMD64 system should **not need to build or manually load the image into Kind**.

### 4. Check the running service through Ingress

**Windows / PowerShell:**

```powershell
curl.exe -i http://localhost:8088/
curl.exe -i http://localhost:8088/healthz
```

**macOS / Linux:**

```bash
curl -i http://localhost:8088/
curl -i http://localhost:8088/healthz
```

Expected for `/`: HTTP 200 and an HTML page containing `Hello from EX.CO version 2!`, `App version: 1.0.1`, and the name of the pod serving the request. `/healthz` returns `200 OK` with body `OK`. The pod name can differ between requests because two replicas are running.

For diagnosis, inspect which image is deployed:

```powershell
kubectl get deployment exco-app -n exco-app -o jsonpath="{.spec.template.spec.containers[0].image}"
kubectl get pods -n exco-app -o wide
```

### 5. Optional: test the service without Kubernetes

Requires Node.js 22 for the first command:

```powershell
node app.js
```

In a second terminal, open `http://localhost:3000/` or check `http://localhost:3000/healthz`. Stop Node with `Ctrl+C`.

Or build and run the image with Docker alone:

```powershell
docker build -t exco-app:local .
docker run --rm -p 8090:3000 --name exco-local exco-app:local
```

Open `http://localhost:8090/` or check `/healthz`. Stop with `Ctrl+C`. This uses a different host port to avoid colliding with the Kind ingress on `8088`.

## CI/CD and how to verify a change

Workflow: `.github/workflows/ci.yml`, triggered by a push to `main` (also supports manual dispatch).

1. GitHub Actions checks out the source and authenticates to **GitHub Container Registry** using `GITHUB_TOKEN`.
2. The Docker image is built and published as `ghcr.io/seannez/exco-devops-exercise:<source-commit-SHA>`.
3. The workflow updates only the `image:` line in `manifests/deployment.yaml`, commits it as `github-actions[bot]`, and pushes to `main`.
4. Argo CD detects the updated Git revision and reconciles the Deployment; Kubernetes replaces pods as part of its rolling-update behavior. **CI does not call `kubectl apply`.**

This was verified by changing the page message and application version, observing a successful workflow, then confirming two new Ready pods running the new GHCR image and obtaining the updated HTML via `http://localhost:8088/`.

To verify the current deployment without changing code:

```powershell
kubectl get applications -n argocd
kubectl get pods -n exco-app
kubectl get deployment exco-app -n exco-app -o jsonpath="{.spec.template.spec.containers[0].image}"
```

When editing code and pushing your own commits, **GitHub Actions also pushes its generated image-update commit**. Before your *next* code commit, synchronize your local branch:

```powershell
git pull --rebase origin main
```

Do not use `git push --force` to resolve a normal non-fast-forward rejection. The GHCR package must remain **public** for anonymous Kubernetes image pulls in this configuration.

## Design decisions and rationale

- **Kind + Terraform:** Kind provides a lightweight, repeatable local multi-node cluster through Docker. Terraform describes the cluster and installs shared services, with an intended `apply`/`destroy` lifecycle.
- **Terraform/Helm for platform services; Argo CD for the app:** Terraform bootstraps foundational components, while the app's desired state is managed declaratively through Git. This avoids competing deployment owners.
- **Traefik NodePort + Kind port mapping:** Exposes the Ingress locally at the predictable URL `http://localhost:8088/` without a cloud load balancer.
- **Commit-SHA image tags:** Each deployment identifies its source revision rather than relying on a mutable `latest` tag. The workflow commits that image reference to Git, preserving Git as the deployment source of truth.
- **Readiness and liveness probes:** `/healthz` is used for both. Readiness keeps non-ready pods out of traffic; liveness restarts unhealthy ones. This simple endpoint checks the HTTP process, not downstream dependencies (there are none in this exercise).
- **Non-root container:** The app runs as the built-in `node` user and listens on unprivileged port `3000`.

## Troubleshooting and issues encountered

### Helm chart downloads failed with HTTP 504

The Argo CD chart download through its original Helm repository was unreliable on the available internet connection. The chart source was changed to the **OCI registry** already present in `terraform/main.tf`:

```hcl
repository = "oci://ghcr.io/argoproj/argo-helm"
chart      = "argo-cd"
version    = "10.15.0"
```

If registry access fails on another network, verify Docker/network connectivity to GHCR and retry the failed Terraform apply. Do not assume the chart is missing solely because an HTTP gateway timed out.

### Fresh Terraform deployment cannot find `kind-exco`

The Helm provider uses `config_context = "kind-exco"`, which is only created after Kind starts. Use the **two-stage first-time bootstrap** shown above: targeted cluster apply, then the full apply. After bootstrap, use ordinary `terraform apply`.

### Argo CD reports `Progressing` for the Ingress

In Kind, an ingress controller may not receive a cloud load-balancer address. Traefik is configured to publish the hostname `localhost` and not rely on its published Service. This allowed the Ingress to report a usable address and Argo CD to show `Healthy`. Do not remove this configuration without considering the local cluster environment.

### `ImagePullBackOff` or a pod remains unready

Check the actual error:

```powershell
kubectl describe pod -n exco-app <POD_NAME>
kubectl get events -n exco-app --sort-by=.lastTimestamp
```

Check that the image in `manifests/deployment.yaml` exists, the GHCR package is **public**, and the machine can reach `ghcr.io`. The final setup pulls its image from GHCR: **manual image imports are not part of the clean installation**. During initial development, a local image was manually imported into worker-node containerd after installing the Kind CLI failed; that workaround is no longer needed.

**Apple Silicon / Linux ARM64:** The tested pipeline builds from the default `ubuntu-latest` runner and **does not explicitly publish an ARM64 image**. An ARM64 node may report `no match for platform in manifest` or a similar pull error. Before reproducing on an ARM64 Mac, update the GitHub Actions workflow to publish multi-platform images, then push the workflow change and let CI update the manifest. For example, add these steps before the existing build step:

```yaml
- uses: docker/setup-qemu-action@v3
- uses: docker/setup-buildx-action@v3
```

And in the existing `docker/build-push-action@v6` step add:

```yaml
with:
  context: .
  push: true
  platforms: linux/amd64,linux/arm64
  tags: ghcr.io/seannez/exco-devops-exercise:${{ github.sha }}
```

This ARM64 adjustment is **guidance, not a tested part of the submitted implementation**. After its workflow succeeds, Argo CD will use the newly committed multi-architecture image reference.

### `kubectl`: connection refused after Docker Desktop restart

This occurred after a local computer crash: Docker containers had restarted but the Kubernetes API server was not ready yet. First verify Docker and the cluster:

```powershell
docker ps
docker port exco-control-plane 6443/tcp
kubectl config current-context
kubectl get nodes
```

If still unavailable, compare the port shown by `docker port` with the server URL in `kubectl config view --minify`, and inspect the API server container's status:

```powershell
kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"
docker exec exco-control-plane crictl ps
```

In the tested recovery, the ports matched; the API server became available after startup completed. There was **no need to destroy or recreate the cluster**.

### HTML still shows an older version just after CI succeeds

Argo CD can be `Synced` while Kubernetes is still completing a rolling update, and the Service may briefly route to an old Ready pod. Check the actual image and code inside the running pod:

```powershell
kubectl get pods -n exco-app -o custom-columns="NAME:.metadata.name,IMAGE:.spec.containers[0].image"
kubectl exec -n exco-app deployment/exco-app -- sh -c "grep -n -E 'Hello from|const VERSION' /app/app.js"
curl.exe http://localhost:8088/
```

The final test returned the updated message and version after the replacement pods became Ready.

### AI error found and corrected

During early local-image testing, an AI-suggested manual import copied an image archive to `/tmp` inside a Kind worker and then asked containerd to read it there. The import failed because the file was not accessible at the expected path. I checked the actual error, copied the archive to `/root/exco-app.tar`, and imported it into containerd successfully. This was a **development-only workaround**; the final deployment uses the public GHCR image directly. The error reinforced the need to verify commands and file paths instead of assuming generated instructions are correct.

A separate CI issue was caught because GitHub did not recognize the initially misplaced workflow and image updates were not reflected in the Deployment. The workflow was moved under `.github/workflows/ci.yml`, the repository's Git write permissions and manifest update step were corrected, and the final GitOps rollout was verified.

### Zero-downtime test limitation

A repeated-request test was started during a version update but was interrupted by a crash of the local computer. Because there is no complete request/error log across the rollout, **zero downtime is not claimed or proven**. The completed checks show a functioning rolling update, readiness probes, and a successful final deployment, but these are not a substitute for the requested continuous-availability measurement.

## What I would change for EKS production

- Replace Kind with an **EKS** cluster across multiple availability zones, managed node groups, and appropriately sized instances.
- Use a **remote Terraform state backend** with locking and separate environment/state boundaries.
- Replace the local NodePort mapping with a production ingress solution such as the **AWS Load Balancer Controller**, configured with HTTPS and ACM certificates.
- Store images in a properly governed registry (GHCR with authenticated pulls or **ECR**); build and publish both AMD64 and ARM64 when needed.
- Add **IAM roles for service accounts / workload identity**, scoped permissions, secrets management, and network policies.
- Add HPA and monitoring/alerting (Prometheus/Grafana or managed alternatives), deployment metrics, logs, and explicit rollback procedures.
- Improve the HTTP probes (startup probe and application/dependency-aware readiness), resource tuning, and security hardening based on workload requirements.

## Cleanup (after the review)

To remove the Terraform-managed resources, run from the repository root:

```powershell
terraform -chdir=terraform destroy
```

**Do not run this before the review:** the exercise asks that the working cluster be left running. Cluster teardown was **not executed as an end-to-end validation step**, so the destroy path is documented but not independently verified.

## AI usage

ChatGPT was used for implementation guidance, debugging, and command review. `ai-prompts.md` contains a **clearly labeled reconstruction of the prompt topics**, since an authoritative verbatim transcript was not available to export into this file. The original chat is the source for exact prompt wording and should remain accessible for review. Generated suggestions were checked against actual command output, Kubernetes status, GitHub Actions runs, and the HTTP response before being accepted.
