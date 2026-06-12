# GitHub Setup Guide — Git Flow (develop → release → main) the Industry Way

This is the exact, click-by-click setup for the flow:
```
feature/* → develop (DEV auto) → QA → release/* (STAGING auto) → UAT → main (approve → PROD)
```
Two developers, CI on every PR, three environments, manual approval before production.

<!-- > Verdict: this is classic **Git Flow** with three deploy environments. It IS a
> real, respected production pattern (common in teams with formal QA/UAT and
> scheduled releases). What makes it "senior-correct": (1) CI runs on every PR
> before merge, (2) staging mirrors prod for UAT, (3) prod is gated by a required
> reviewer. All wired below. -->

### Branch → environment → server map
```
 branch          GitHub environment   server         trigger
 ─────────       ──────────────────   ───────        ───────────────
 develop         development          cicd-frontend-dev      auto
 release/*       staging              cicd-frontend-staging  auto
 main            production           cicd-frontend-prod     manual approval
```

---

## SETUP 1 — Create the repo and the branches

```bash
cd 03-deploy-frontend-to-vms

# generate the lockfile so `npm ci` works in CI (one-time)
cd app && npm install && cd ..

git init
git add .
git commit -m "chore: initial cicd frontend"
git branch -M main
git remote add origin https://github.com/<you>/cicd-frontend.git
git push -u origin main

# create develop FROM main, push it
git switch -c develop
git push -u origin develop
```

Result: GitHub has `main` and `develop`. `release/*` branches are CUT on demand
at release time (see the flow section).

```
origin
 ├── main      ← production source of truth (deploys to PROD)
 ├── develop   ← integration branch        (deploys to DEV)
 └── release/* ← cut from develop per release (deploys to STAGING)
```

---

## SETUP 2 — Environments + secrets (3 deploy targets + approval gate)

`GitHub repo → Settings → Environments`. Create THREE.
Get the 3 server IPs from `terraform output server_public_ips`.

### a) development  → DEV server
1. **New environment** → `development` → Configure.
2. **Environment secrets → Add secret** (all three):
   - `SSH_HOST` = **DEV** EC2 public IP
   - `SSH_USER` = `ubuntu`
   - `SSH_KEY`  = full contents of `cicd-frontend-key.pem` (PRIVATE key)
3. (Optional) **Deployment branches** → Selected → add `develop`.

### b) staging  → STAGING server
1. **New environment** → `staging` → Configure.
2. **Environment secrets**: `SSH_HOST` = **STAGING** IP, `SSH_USER` = `ubuntu`,
   `SSH_KEY` = same private key.
3. (Optional) **Deployment branches** → Selected → add `release/*`.

### c) production  → PROD server
1. **New environment** → `production` → Configure.
2. ✅ **Required reviewers** → add **yourself** (and/or the other dev).
   → THIS is the manual-approval gate before prod.
3. (Optional) **Deployment branches** → Selected → add `main`.
4. **Environment secrets**: `SSH_HOST` = **PROD** IP, `SSH_USER` = `ubuntu`,
   `SSH_KEY` = same private key.

```
development            staging              production
 ├ SSH_HOST=DEV_IP       ├ SSH_HOST=STG_IP        ├ SSH_HOST=PROD_IP
 ├ SSH_USER=ubuntu       ├ SSH_USER=ubuntu        ├ SSH_USER=ubuntu
 ├ SSH_KEY=<priv key>    ├ SSH_KEY=<priv key>     ├ SSH_KEY=<priv key>
 ├ Require PR            ├ Require PR             ├ Require PR
 └ Require Status Checks └ Require Status Checks  ├ Require Status Checks
                                                  ├ Required reviewer: you  ← APPROVAL
                                                  ├ Block Force Push
                                                  ├ Block Delete
                                                  └ Dismiss Stale Reviews
```

> Same key works for both because Terraform put the same public key on both EC2s.

---
## SETUP 3 — Branch protection (forces the PR + CI + review)

`Settings → Branches → Add branch ruleset` (or "Add rule" classic).

For **main** (strictest):
- ✅ Require a pull request before merging
  - ✅ Require approvals: **1** (the other developer reviews)
- ✅ Require status checks to pass before merging
  - select the **CI / build-test** check (appears after CI runs once)
- ✅ Require branches to be up to date before merging
- ✅ Do not allow bypassing the above (optional, stricter)

For **develop** (lighter): require PR + the CI status check (approvals optional).

```
main    : PR required + 1 approval + CI must pass   ← protected hardest
develop : PR required + CI must pass                ← integration gate
```

This is what stops anyone (including you) from pushing broken code straight to
main — the #1 thing interviewers check that you understand.

---

## SETUP 4 — Workflows (already in this repo)

`.github/workflows/`:
- `ci.yml`     → build/lint/test on every PR + push to develop/release/main.
- `deploy.yml` → develop→DEV, release/*→STAGING, main→PROD (approval).

Nothing to do except make sure they're committed and pushed.

---

## THE FULL FLOW — daily life of the 2 developers

```
1) FEATURE WORK
  git switch develop && git pull
  git switch -c feature/login        # branch off develop
  ...code... ; git commit -m "feat: login"
  git push -u origin feature/login
  open PR:  feature/login  ──►  develop
      │ CI runs. Teammate reviews + approves.
      ▼ merge
  develop updated ──► deploy.yml ──► DEV server (auto)   → QA tests on http://DEV_IP

2) CUT A RELEASE (when develop is QA-approved)
  git switch develop && git pull
  git switch -c release/1.2.0        # cut release branch
  git push -u origin release/1.2.0
      ▼ push to release/*
  release/1.2.0 ──► deploy.yml ──► STAGING server (auto)  → UAT on http://STAGING_IP
  (bug fixes go ONTO the release/* branch; they redeploy staging)

3) SHIP TO PROD
  open PR:  release/1.2.0  ──►  main
      │ CI runs again. Review.
      ▼ merge
  main updated ──► deploy.yml ──► deploy-prod job
                     │ "production" env = Waiting: Review required
                     ▼ you click  Approve
                   PROD server updated  ──► http://PROD_IP
  # then merge main (or release) back into develop so fixes aren't lost:
  git switch develop && git merge main && git push
  # tag the release
  git tag -a v1.2.0 -m "release 1.2.0" && git push --tags
```

### Rollback (say this in interviews)
- Re-run the last successful `main` deploy from the Actions tab, OR
- `git revert` the bad commit on `main` → pipeline redeploys the previous good state.

---

## Interview soundbite (memorize)
> "We use Git Flow with three environments. Feature branches PR into `develop`,
> which auto-deploys to DEV for QA. For a release we cut a `release/*` branch that
> auto-deploys to STAGING for UAT; fixes land on the release branch. When UAT
> passes we PR the release into `main`; merging triggers the prod deploy, gated by
> a required-reviewer approval in a GitHub Environment. CI (build + test) runs on
> every PR as a required status check, we build the artifact once and promote the
> same one, tag releases, and roll back by re-running the last good deploy or
> reverting."

---

## Common gotchas (so you're not caught out)
| Symptom | Cause / fix |
|---|---|
| Prod never deploys | It's waiting on the required-reviewer approval (Actions tab) |
| `npm ci` fails | `package-lock.json` not committed |
| SSH "permission denied" | Wrong `SSH_KEY`/`SSH_USER`, or your EC2 SG SSH rule is your IP only and the GitHub runner IP differs — for SCP/SSH from Actions, the runner connects over port 22, so SG must allow `0.0.0.0/0` on 22 OR use a self-hosted runner. (See note below.) |
| CI check not selectable in branch rule | Run the workflow once first so GitHub learns the check name |
| STAGING never deploys | release branch must match `release/**` (e.g. `release/1.2.0`) |

### Important SSH note for THIS setup
Your Terraform locked SSH (port 22) to **your IP only**. GitHub-hosted runners have
**different, changing IPs**, so the deploy's SSH/SCP will be blocked. Two fixes:
1. **Simplest for learning:** widen the SG SSH rule to `0.0.0.0/0` (set
   `my_ip = "0.0.0.0/0"` in tfvars, `terraform apply`). Less secure but fine for a demo.
2. **Production-correct:** use a **self-hosted runner** inside your VPC, or deploy via
   AWS SSM instead of raw SSH. (We can do this when you reach the Security module.)

<BR>

---
# Setup Organzation


For GitHub **access management**. There are two ways depending on whether the repo is personal or in an organization.

## Option A — Personal repo (simplest, for 2 devs)

`Repo → Settings → Collaborators` (called "Collaborators and teams")
1. Click **Add people**.
2. Enter the developer's **GitHub username / email**.
3. Pick a **role** (see table below) → send invite.
4. They get an email/notification → must **Accept** before they can push.

```
Settings → Collaborators → Add people → <username> → choose role → invite
                                                          │
                                          developer accepts the email invite
```

## Option B — Organization repo (the "industry" way for teams)

If the repo lives under a GitHub **Organization**, you manage access by **Teams**, not individuals — this scales and is what real companies do.
```
Org → Teams → create "developers" team → add members
Repo → Settings → Collaborators and teams → Add team "developers" → role: Write
```
Benefit: add/remove a person from the team once, and their repo access updates everywhere.

## The permission roles (what each can do)

| Role | Can push? | Can merge PRs | Can change settings | Use for |
|---|---|---|---|---|
| **Read** | ❌ | ❌ | ❌ | viewers/stakeholders |
| **Triage** | ❌ | ❌ | ❌ | issue/PR triagers |
| **Write** | ✅ push branches + open PRs | ✅ (if branch rules allow) | ❌ | **your developers** ← pick this |
| **Maintain** | ✅ | ✅ | partial (no destructive) | team leads |
| **Admin** | ✅ | ✅ | ✅ everything | you (owner) |

**For your two developers: give them `Write`.** That lets them push feature branches and open PRs, but — because of the **branch protection** you set up — they still **cannot push directly to `main` or `develop`**; they must go through a PR + review. That combination (Write role + branch protection) is exactly the secure, production-correct setup.

## How it ties to your flow
```
Developer (Write role)
   │ can: push feature/* branches, open PRs
   │ CANNOT: push straight to main/develop (blocked by branch protection)
   ▼
   PR → CI runs → review → merge → pipeline deploys
```

## Authentication note (so their `git push` actually works)
Username/password push was removed by GitHub. Each developer pushes using **one** of:
- **HTTPS + Personal Access Token (PAT)** — they create a fine-grained PAT (`Settings → Developer settings → Personal access tokens`) and use it as the password, or
- **SSH key** — they add their public key under `Settings → SSH and GPG keys`, then clone via the `git@github.com:...` URL.

SSH is the cleaner long-term choice.

<BR>

---
<!-- ### Accounts:
 -  `Email`: princewillopah@gmail.com 
 -  `username`: princewillopah
<br><br>
 - `Email`: princewillopah.dev@gmail.com 
 - `username`: princewill-opah
<br><br>
 - `Email`: princewillopah@outlook.com 
 - `username`: princewillopah1 -->
# WHAT DEVELOPER MUST DO

Nice — you have the org `ievicon` with two devs. Here's exactly what's next, then a deep dive on both auth methods.

## Step 1 — Create the repo INSIDE the organization

You don't move a personal repo; you create it under the org (or transfer it later).
```
github.com → top-right "+" → New repository
   Owner:  ievicon          ← pick the ORG here, not your personal account
   Name:   cicd-frontend
   Private (recommended)
   Create repository
```
If you already pushed it to your personal account, you can move it:
`Repo → Settings → General → Danger Zone → Transfer ownership → ievicon`.

## Step 2 — Give the two devs access (org way = Teams, not individuals)

Adding them to the org isn't enough — org membership ≠ repo access. You grant **repo access**, ideally via a **Team**:

```
1. Org ievicon → Teams → New team  → name: "developers" → add the 2 members
2. Your repo → Settings → Collaborators and teams → Add teams
3. Select "developers" → Role: Write → Add
```

```
ievicon (org)
 └── Team: developers  ──(Write)──►  repo: cicd-frontend
        ├── princewill-opah
        └── princewillopah1
```

**Role = Write.** With your branch protection, Write lets them push `feature/*` branches and open PRs, but they **cannot** push directly to `develop`/`main`. That's the secure, production-correct combo.

After this, each dev sees the repo at `github.com/ievicon/cicd-frontend` and can clone it. Now they just need to **authenticate** their `git push`. Here are both methods in depth.

---

# Deep dive: the two authentication methods

GitHub removed account-password auth in 2021. Every push uses either a **PAT over HTTPS** or an **SSH key**. Here's how each works, end to end.

## How Git auth works (mental model)
```
your laptop ── git push ──► GitHub
                  │
        proves WHO you are via:
        ┌─────────────────────────────┬─────────────────────────────┐
        │ HTTPS + PAT                  │ SSH key                     │
        │ remote: https://github.com/ │ remote: git@github.com:...  │
        │ sends a TOKEN as password    │ sends a cryptographic       │
        │ over TLS                     │ signature (private key)     │
        └─────────────────────────────┴─────────────────────────────┘
```

---

## METHOD 1 — HTTPS + Personal Access Token (PAT)

A PAT is a long secret string that replaces your password. There are **two kinds**:
- **Fine-grained** (newer, recommended) — scoped to specific repos + specific permissions, with an expiry.
- **Classic** (older) — broad scopes, less granular.

### Each developer does this:
```
1. github.com → top-right avatar → Settings
2. Developer settings (bottom of left menu)
3. Personal access tokens → Fine-grained tokens → Generate new token
4. Configure:
     Token name:    laptop-cicd
     Expiration:    90 days (rotate regularly)
     Resource owner: ievicon            ← MUST pick the org to access org repos
     Repository access: Only select repositories → cicd-frontend
     Permissions → Repository permissions:
         Contents:        Read and write   ← needed to push
         Pull requests:   Read and write   ← needed to open PRs
         Metadata:        Read (auto)
5. Generate token → COPY IT NOW (shown once). Treat it like a password.
```

> Org note: fine-grained tokens for an org may require the **org owner to approve**
> the token (Org → Settings → Personal access tokens → pending requests). If their
> token "can't see" the repo, that approval is usually why.

### Using the PAT
```bash
git clone https://github.com/ievicon/cicd-frontend.git
# when prompted:
#   Username: <their github username>
#   Password: <paste the PAT — NOT their account password>
```
Avoid re-typing every push by caching it:
```bash
# Linux: store encrypted-ish in a file (simple)
git config --global credential.helper store
# better: GitHub CLI handles it for you
gh auth login        # choose HTTPS, paste/authorize → done
```

### PAT pros / cons
| 👍 | 👎 |
|---|---|
| Works anywhere HTTPS works (firewalls rarely block 443) | Tokens expire → must rotate |
| Fine-grained per-repo permissions | A leaked token = repo access until revoked |
| Easy for CI/automation | Slightly more friction (caching) |

---

## METHOD 2 — SSH key

Instead of a secret string, you prove identity with a **key pair**: a private key stays on the laptop, the matching public key is uploaded to GitHub. Git signs each connection.

```
laptop:  ~/.ssh/id_ed25519       (PRIVATE — never share)
         ~/.ssh/id_ed25519.pub   (PUBLIC  — upload to GitHub)
                     │
GitHub stores the public key against the dev's account.
On push, the laptop signs a challenge with the private key;
GitHub verifies it with the stored public key. No secret travels.
```

### Each developer does this:
```bash
# 1) generate a key pair (ed25519 is the modern default)
ssh-keygen -t ed25519 -C "their-email@example.com"
#   press Enter for default path ~/.ssh/id_ed25519
#   set a passphrase (recommended)

# 2) copy the PUBLIC key
cat ~/.ssh/id_ed25519.pub      # copy the whole line (ssh-ed25519 AAAA... email)
```
```
3) github.com → Settings → SSH and GPG keys → New SSH key
     Title: laptop
     Key:   <paste the public key>
   Add SSH key
```
```bash
# 4) test it
ssh -T git@github.com
#   → "Hi <username>! You've successfully authenticated..."

# 5) clone via the SSH URL (note the git@ form, not https)
git clone git@github.com:ievicon/cicd-frontend.git
```

If you already cloned via HTTPS, switch the remote to SSH:
```bash
git remote set-url origin git@github.com:ievicon/cicd-frontend.git
```

### SSH pros / cons
| 👍 | 👎 |
|---|---|
| No tokens to rotate; key can live for years | Some corporate networks block port 22 |
| Passphrase-protected; nothing secret sent over wire | Slightly more setup (keygen, agent) |
| Great for daily developer use | Per-machine (each laptop needs its own key) |

---

## Which should YOUR developers use?

| Situation | Recommendation |
|---|---|
| Daily coding on their own laptops | **SSH** — set once, no rotation hassle |
| Restricted network blocking port 22 | **PAT over HTTPS** (443 almost always open) |
| CI/CD, scripts, automation | **PAT** (or deploy keys / GitHub App) |

For two developers on their own machines, I'd tell them: **use SSH for daily work**, and keep a fine-grained PAT as a backup for HTTPS-only situations.

```
recommended:  developers → SSH keys (daily)
              automation/CI → PAT or built-in GITHUB_TOKEN
```

---

## Putting it together — what each dev runs once they have access
```bash
# (SSH path)
ssh-keygen -t ed25519 -C "me@email"      # then add the .pub to GitHub
git clone git@github.com:ievicon/cicd-frontend.git
cd cicd-frontend
git switch develop
git switch -c feature/my-task
# ...work...
git push -u origin feature/my-task       # then open a PR → develop
```

That's the complete picture: **create the repo under `ievicon` → add the `developers` team with Write → each dev authenticates via SSH (or PAT) → they push feature branches and open PRs**, which your branch protection + pipeline then handle.

Want me to add this org/auth section cleanly into your GITHUB-SETUP.md (you already started an "Accounts" note there), or move on to actually pushing the repo and wiring the three environments?