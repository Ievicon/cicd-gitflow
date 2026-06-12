# 03 — Deploy a React Frontend to TWO VMs (dev + prod) with Approval

This is the main project. Build a Vite/React app, deploy it to a **dev** VM
automatically, then to a **prod** VM only **after you approve**.

## Architecture
```
 you ─push→ main ─► GitHub Actions
                        │ build (npm run build → dist/)
                        ▼
                  deploy-dev ──ssh/scp──► DEV VM  (nginx) http://DEV_IP
                        │
                        ▼
                  ⛔ APPROVAL (production environment, required reviewer)
                        │ you click "Approve" in the Actions UI
                        ▼
                  deploy-prod ─ssh/scp──► PROD VM (nginx) http://PROD_IP
```

## Why "build once, deploy many"
The `build` job runs ONCE and uploads a `dist` artifact. Both dev and prod deploy
the **exact same artifact**. This guarantees prod runs what you tested in dev — a
core CI/CD principle (no rebuild drift).

---

## STEP 1 — Get two VMs (cheapest options)

| Option | Cost | Notes |
|---|---|---|
| **Oracle Cloud Always Free** | **$0 forever** | 2–4 ARM VMs free; best free real cloud |
| **AWS EC2 t3.micro ×2** | free tier / ~$8 each | you already have AWS; easy |
| **Hetzner CX22 ×2** | ~€4/mo each | cheapest paid, very clean |
| **Local: multipass** | $0 | 2 local Ubuntu VMs; great for practice, no internet SSH |

For the real "deploy over the internet" experience, use Oracle Free, AWS, or Hetzner.
For zero-cost local practice, use multipass (commands at the bottom).

### Prepare EACH VM (dev and prod) — Ubuntu
```bash
ssh ubuntu@<VM_IP>
sudo apt update && sudo apt install -y nginx
sudo systemctl enable --now nginx
# allow your SSH key (the pipeline uses a key, not a password):
#   put the PUBLIC key in ~/.ssh/authorized_keys (cloud usually does this at create)
```
Open ports 22 (SSH) and 80 (HTTP) in the VM firewall/security group.

---

## STEP 2 — Create an SSH key pair for the pipeline
```bash
ssh-keygen -t ed25519 -C "cicd" -f ~/.ssh/cicd_key
# PUBLIC key → each VM's ~/.ssh/authorized_keys
ssh-copy-id -i ~/.ssh/cicd_key.pub ubuntu@<DEV_IP>
ssh-copy-id -i ~/.ssh/cicd_key.pub ubuntu@<PROD_IP>
# PRIVATE key (~/.ssh/cicd_key) → goes into GitHub as the SSH_KEY secret
```

---

## STEP 3 — Create a GitHub repo & push this app
```bash
cd 03-deploy-frontend-to-vms
git init && git add . && git commit -m "feat: cicd frontend"
git branch -M main
git remote add origin https://github.com/<you>/cicd-frontend.git
git push -u origin main
```
Also generate the lockfile locally first so `npm ci` works:
```bash
cd app && npm install   # creates package-lock.json — commit it
```

---

## STEP 4 — Configure Environments + the approval gate (GitHub UI)
`Settings → Environments`:
1. New environment **development**. Add secrets: `SSH_HOST` (dev IP), `SSH_USER`
   (`ubuntu`), `SSH_KEY` (paste the PRIVATE key).
2. New environment **production**. Add the SAME three secrets with PROD values.
3. On **production**, tick **Required reviewers** and add yourself → THIS is the
   approval gate.

```
production environment
  ├── Required reviewers: [you]      ← pipeline PAUSES here until you Approve
  └── secrets: SSH_HOST, SSH_USER, SSH_KEY (prod values)
```

---

## STEP 5 — Run it
- Push to `main` (or use the **Run workflow** button).
- Watch **Actions** tab: `build → deploy-dev` run automatically.
- `deploy-prod` shows **"Waiting — Review required"**. Click **Review deployments
  → Approve**. It then deploys to prod.
- Visit `http://DEV_IP` and `http://PROD_IP` — the page shows which environment.

---

## The full flow (what to narrate in an interview)
```
1. Developer pushes to main
2. CI runner checks out code, npm ci, npm run build → dist artifact
3. deploy-dev: scp dist → DEV VM, swap nginx webroot, reload  (automatic)
4. deploy-prod: GitHub blocks on the production environment's required reviewer
5. Human approves → same artifact scp'd → PROD VM, nginx reload
6. Rollback = re-run an older successful workflow (same artifact model)
```

---

## (Optional) Local 2-VM practice with multipass
```bash
sudo snap install multipass
multipass launch --name dev  --cpus 1 --memory 1G 22.04
multipass launch --name prod --cpus 1 --memory 1G 22.04
multipass exec dev  -- sudo apt update && multipass exec dev  -- sudo apt install -y nginx
multipass exec prod -- sudo apt update && multipass exec prod -- sudo apt install -y nginx
multipass list      # shows the IPs to use as SSH_HOST
```
Note: GitHub-hosted runners can't reach your laptop's local VMs over the internet.
For local VMs, either use a **self-hosted runner** or practice the SSH/deploy steps
manually first, then move to a cloud VM for the real pipeline run.
