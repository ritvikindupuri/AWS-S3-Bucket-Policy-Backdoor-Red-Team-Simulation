# AWS-S3-Bucket-Policy-Backdoor-Red-Team-Simulation

# AWS S3 Bucket Policy Backdoor — Red Team Simulation (Stratus Red Team)

A controlled, production-safe adversary emulation that backdoors an S3 bucket policy to grant unauthorized object access, then verifies, reverts, and fully cleans up.

---

## TL;DR

- Objective: Show how an attacker can enable data exfiltration by changing an S3 bucket policy — and how to test this safely.
- Method: Stratus Red Team automates warmup → detonate → revert → cleanup; Terraform manages ephemeral infra; AWS CLI validates state.
- Result: Policy successfully attached during detonation, removed on revert, and all resources destroyed on cleanup (COLD).

---

## Skills / Hiring Signals

- Cloud control-plane attack simulation (S3 policy manipulation)
- IaC and automation discipline (Terraform + Stratus lifecycle)
- Evidence-driven validation (CLI before/after proofs)
- Safety guardrails (least-priv IAM, teardown, scoped non-prod)

---

## Versions / Requirements

- Stratus Red Team: current at time of test
- Terraform: v1.x
- AWS CLI: v2.x
- AWS Account: non-production, with a role limited to this technique
- jq (optional) for CLI JSON reading

---

## Architecture

<img width="800" height="336" alt="image" src="https://github.com/user-attachments/assets/34e6a5f4-d106-46fc-b936-be599f8d71ae" />

*Figure 1 — Red team host orchestrates Stratus against the AWS environment, backdooring an S3 bucket policy, validating access/policy state, then reverting and cleaning up.*

**Components**
- Attacker zone: host with Stratus, Terraform, and AWS CLI.
- AWS environment: ephemeral S3 bucket and bucket policy (optionally a test IAM role).
- Flow: verify baseline → detonate (attach malicious policy) → verify success → revert (remove policy) → cleanup (destroy infra).

---

## Minimal IAM Scope (example)

Use a tightly scoped role in a non-prod account. Example (adjust ARNs to your env and add logging/assume-role as needed):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": ["s3:GetBucketPolicy","s3:PutBucketPolicy","s3:DeleteBucketPolicy"], "Resource": ["arn:aws:s3:::stratus-red-team-*"] }
  ]
}
Reproduce Safely
Run only in an owned, isolated account with explicit approvals.

bash
Copy
Edit
# Pre-reqs: Stratus installed; Terraform and AWS CLI available; AWS auth scoped with least privilege.

# 1) Provision prerequisites (bucket, etc.)
stratus warmup aws.exfiltration.s3-backdoor-bucket-policy
stratus status aws.exfiltration.s3-backdoor-bucket-policy   # expect: WARM

# Discover the technique bucket name (check Stratus output) and set:
export TECH_BUCKET=<technique-bucket-name>

# 2) Baseline check — bucket should have no policy
aws s3api get-bucket-policy --bucket "$TECH_BUCKET"          # expect: NoSuchBucketPolicy

# 3) Detonate — attach malicious bucket policy
stratus detonate aws.exfiltration.s3-backdoor-bucket-policy
stratus status aws.exfiltration.s3-backdoor-bucket-policy   # expect: DETONATED

# 4) Verify — policy now present (malicious backdoor)
aws s3api get-bucket-policy --bucket "$TECH_BUCKET"

# 5) Revert — remove the malicious policy only
stratus revert aws.exfiltration.s3-backdoor-bucket-policy
stratus status aws.exfiltration.s3-backdoor-bucket-policy   # expect: WARM

# 6) Confirm removal
aws s3api get-bucket-policy --bucket "$TECH_BUCKET"          # expect: NoSuchBucketPolicy

# 7) Cleanup — tear everything down
stratus cleanup aws.exfiltration.s3-backdoor-bucket-policy
# expect: COLD
Evidence and Results

<img width="800" height="368" alt="image" src="https://github.com/user-attachments/assets/087da4a7-879f-410b-a636-df251d19466e" />

Figure 2 — Technique transitions to DETONATED and get-bucket-policy returns a policy JSON, confirming the malicious attachment and the newly enabled access path.

<img width="800" height="254" alt="image" src="https://github.com/user-attachments/assets/460ec9dd-5708-40e0-8e2b-8e0c85486778" />

Figure 3 — After stratus revert, status returns to WARM and get-bucket-policy yields NoSuchBucketPolicy, proving the backdoor removal while keeping infra available.

<img width="800" height="169" alt="image" src="https://github.com/user-attachments/assets/c32a6374-5ca1-4dc3-a451-840c44d83a52" />

Figure 4 — stratus cleanup destroys prerequisites via Terraform, returning the technique to COLD (production-safe state).

What This Proves
S3 access can be covertly enabled by policy manipulation without touching object data.

Lifecycle automation prevents drift and ensures safe rollback.

Command-level checks provide clear before/after evidence for auditability.

ATT&CK-Style Mapping (conceptual)
T1567.002 — Exfiltration to Cloud Storage (exfiltration over web service)

Related: control-plane abuse; defense evasion via policy changes

Blue-Team Detection and Hardening
Detect

CloudTrail events: PutBucketPolicy, DeleteBucketPolicy, GetBucketPolicy

EventBridge rules on policy changes for sensitive buckets

AWS Config conformance rules for restrictive S3 policies

Macie / DLP alerts on sensitive object access or movement

Prevent

Least privilege for identities allowed to modify S3 bucket policies

S3 Block Public Access and organization-level SCP guardrails

Change-control workflows for policy edits on crown-jewel buckets

Resource tagging and boundary policies to protect sensitive stores

Repository Structure

.
├─ images/
│  ├─ s3-bucket-policy-exploit-architecture.png      # Figure 1
│  ├─ console-detonate-policy-proof.png              # Figure 2
│  ├─ console-revert-warm-nosuchbucketpolicy.png     # Figure 3
│  └─ console-cleanup-cold.png                       # Figure 4
└─ README.md
Rename your screenshots to the filenames above and place them in images/ so the references render.

Safety, Scope, and Ethics
Use synthetic or non-sensitive data only; never target customer data.

Run in isolated, non-production accounts with clear approvals.

Scope IAM permissions narrowly and rotate credentials if used for testing.

Retain evidence (CLI output, logs) for audit and learning.
