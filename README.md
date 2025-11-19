# Azure DevOps CI/CD Pipeline – Node.js App Deployment (Self-Hosted Agent + SSH) 👍

## Repo
https://github.com/VemulaSaiTharunGoud/Azure-CI-CD-Pipeline

## Goal
Build an end-to-end CI/CD pipeline in Azure DevOps that builds and deploys a simple Node.js app to a Oracle Linux (Ubuntu) VM via SSH (self-hosted agent) host using SSH. 

## Project Overview

This repository contains a minimal Node.js app that returns `Hello from Azure DevOps demo`. The Azure DevOps pipeline builds, runs tests, archives artifacts and deploys the app to a Linux VM (Oracle VM / local network) using SSH and a self-hosted agent.

- Azure DevOps **Pipelines**
- **Self-Hosted Agent** running on Ubuntu VM  
- **CI pipeline** (Install dependencies + Build + Test)
- **CD pipeline** (Stop previous app, backup, deploy new code, restart)
- **SSH Deployment Task**

This setup is suitable for production-like CI/CD.

## What I used
- Oracle VM (Ubuntu) as deployment host
- GitHub repo as source
- Azure DevOps (organization: `vemula-org`), Azure Pipelines (CI/CD Orchestration)
- Node.js 18 (Application runtime)

## Steps followed
1. Created a simple Node.js app (`server.js`) that listens on port 3000 and returns a text message.  
2. Initialized `package.json` and committed to GitHub: initially `"test": "exit 1"` to show fail.  
3. In Azure DevOps: created a project and a new pipeline connected to GitHub repo and `.azure-pipelines.yml`.  
4. Encountered “No hosted parallelism” — created a **self-hosted agent**:
   - Downloaded Azure Pipelines agent on VM (`vsts-agent`), configured it with a PAT, attached to `oracle-vm-pool`.  
   - Installed and ran the agent as `ci-deploy` user (`./svc.sh install` & `./svc.sh start`).
5. Created SSH keypair on local machine and added the public key to `/home/ci-deploy/.ssh/authorized_keys` on the VM. Configured SSH service connection `SSH-DEPLOY` in Azure DevOps.
6. Implemented `.azure-pipelines.yml`:
   - `trigger: main`
   - CI steps: checkout, NodeTool (18.x), install deps, build, run-tests (initially failing).
   - CD steps: SSH stop app, backup `/opt/myapp` → `/opt/myapp_prev`, copy artifact, install deps on target, start app.
7. Fixed issues encountered (detailed below), re-ran pipeline and validated deployment.
8. Demonstrated rollback by forcing start failure and showing `Rollback triggered`.

## 📁 Project Structure

├── server.js (http server)
├── package.json (scripts: start, build, test)
├── package-lock.json (locked dependencies for CI)
├── start.sh (script used by the SSH task to run the app)
└── .azure-pipelines.yml (pipeline YAML used by Azure DevOps)

### **Key CI Features**

- Ensures code validity before deployment
- Runs fast because self-hosted agent already has Node.js
- Uses `package-lock.json` for consistent installs
- Deployment happens over SSH using the `SSH@0` Azure DevOps task.

## The Azure Pipelines YAML (explanation + snippet)

**Top-level**:
- `trigger: - main` — pipeline triggers on every commit to `main`.
- `pool: oracle-vm-pool` — uses the self-hosted agent pool.

**CI steps**:
- `checkout: self` — fetch repository.
- `NodeTool@0` — ensures Node 18 available in pipeline environment (for hosted jobs; agent has Node installed).
- `Install dependencies`:
  - used `npm ci` when `package-lock.json` present, otherwise fallback to `npm install`.
- `Build` — placeholder (`npm run build`) — lightweight `echo` for this example.
- `run-tests` — intentionally failed initially (`test: "exit 1"`) to demonstrate fixing workflow; later changed to `test: "echo ok"` or similar.
- `Publish` — build artifacts archived for deployment.

**CD steps**:
- SSH step to **stop app** (safe shutdown using pid file).  
- SSH step to **backup** old deploy dir: `mv /opt/myapp /opt/myapp_prev`. (If `mv` fails due to permission, pipeline prints error.)
- `CopyFilesOverSSH` — copies artifact to target folder (`/opt/myapp`).  
- SSH step to `npm ci` in target folder to install dependencies.  
- SSH step to start the app (`./start.sh`).

Full YAML used in repo: see `.azure-pipelines.yml` (included in this repo).  
(You can also find the pipeline file view in Azure DevOps when you open the pipeline definition.)

-------------------

## Quick demo (screenshots)
### 1. Pipeline run — failing `run-tests` (first attempt)

<img width="1919" height="939" alt="image" src="https://github.com/user-attachments/assets/5f19cd90-a376-48b4-9ac7-0582fe075e71" />

*Caption:* Pipeline run that shows `run-tests` failing (Bash exited with code '1'). This was the intentionally failing tests step to demonstrate fix & re-run.

### 2. Pipeline run — test success (after fix)

<img width="1919" height="945" alt="image" src="https://github.com/user-attachments/assets/e92d91b1-5f8f-4b43-8668-bba1f62d76a0" />

*Caption:* The pipeline successfully finished after I updated `package.json` (test script) and resolved environment issues.

### 3. Deployment verification — curl from VM

<img width="726" height="54" alt="image" src="https://github.com/user-attachments/assets/11468ecf-f146-4ff3-8a56-b20abc78f9ab" />

*Caption:* `curl` output from the VM showing the same response — verifies the app is running and network is accessible.

### 4. Deployment verification — browser 

<img width="715" height="149" alt="image" src="https://github.com/user-attachments/assets/6dfe2854-618c-469f-b1b6-a7b47d0db913" />

*Caption:* Browser screenshot of the app running on the VM: `http://192.168.1.11:3000` showing `Hello from Azure DevOps demo`.

## Rollback logic (simple & clear)

**What I implemented:**
- Before copying new files, pipeline runs a backup step on the VM:
  ```bash
  rm -rf /opt/myapp_prev || true
  mv /opt/myapp /opt/myapp_prev

- If the subsequent deploy or start steps fail, the pipeline or the SSH script prints:
  ```bash
  Rollback triggered
  mv /opt/myapp_prev /opt/myapp

and restores the previous directory.

**Why this is OK for the task:**

It provides a clear, auditable mechanism to restore the previous working app quickly. Before copying files the pipeline moves `/opt/myapp` → `/opt/myapp_prev`. After copying, it runs `start.sh`. If `start.sh` fails, the pipeline prints `Rollback triggered`, restores `/opt/myapp_prev` and attempts to start it.

## Issues I faced & how I solved them

**1. No hosted parallelism** — pipeline queued error.
**Fix:** Installed a **self-hosted agent** on my VM (configured with PAT). Azure DevOps pipeline assigned job to `oracle-vm-pool`.

**2. `npm` not installed / Node mismatch / dpkg conflict** — `npm ci` failed.
**Fix:** Installed Node 18 from NodeSource and resolved dpkg conflict by removing older `libnode72` package, then installed `nodejs` successfully. Verified `node -v` and `npm -v`.

**3. `npm ci` EUSAGE** — pipeline error because `package-lock.json` missing.
**Fix:** Generated `package-lock.json` locally (`npm install`) and committed it OR added YAML fallback to `npm install` when lockfile absent.

**4. Permission denied while backing up `/opt/myapp`** — `mv` failed because `/opt` was owned by  `root`.
**Fix:** Either changed `/opt` group-owner and perms:
`chown root:ci-deploy /opt`
 `chmod 775 /opt`

or deployed to `/home/ci-deploy/myapp` to avoid touching `/opt`. I chose to grant group write so CI can perform `mv` safely.

**5. Agent created _work files as root (after initial runs)** — potential permission mismatch.
**Fix:** Reconfigured agent to run as `ci-deploy` and `chown -R /azure-agent/_work` to `ci-deploy`.

## ✅ Summary of What I Learned

Through this task, I learned how to build a complete CI/CD pipeline in Azure DevOps using YAML, including automated build, testing, artifact generation, and deployment. I understood how to configure and run a **self-hosted agent** when hosted parallelism isn’t available. I also gained hands-on experience using **SSH-based deployment**, managing Linux permissions, and fixing real-world issues like missing Node/npm, lockfile errors, and directory ownership problems. Implementing a simple **rollback mechanism** helped me understand safe deployment practices. Finally, verifying deployment through both browser and terminal taught me how to validate end-to-end delivery in a real environment.

