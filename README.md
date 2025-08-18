# AWS S3 Bucket Policy Backdoor — Red Team Simulation (Stratus Red Team)

A controlled, production-safe adversary emulation that backdoors an S3 bucket policy to grant unauthorized object access, then verifies, reverts, and fully cleans up.

---

## TL;DR

- Objective: demonstrate how changing an S3 bucket policy can silently enable data exfiltration.
- Method: Stratus Red Team automates warmup → detonate → revert → cleanup; Terraform provisions/tears down prerequisites; AWS CLI validates state.
- Result: policy attached during detonation, removed on revert, and all resources destroyed on cleanup (COLD).

---

## Skills / Hiring Signals

- Cloud control-plane attack simulation (S3 bucket policy manipulation)
- Infrastructure-as-Code and lifecycle hygiene (Terraform + Stratus)
- Evidence-driven validation (CLI before/after proofs)
- Safety guardrails (scoped IAM, non-prod isolation, full teardown)

---

## Versions / Requirements

- Stratus Red Team: current (technique `aws.exfiltration.s3-backdoor-bucket-policy`)
- Terraform: v1.x
- AWS CLI: v2.x
- AWS Account: non-production only, with a tightly scoped role
- jq (optional) for JSON formatting

---

## Architecture

<img width="800" height="336" alt="image" src="https://github.com/user-attachments/assets/d4064f8e-7428-4cbc-bc06-853b1278eca2" />
*Figure 1 — Red team host orchestrates Stratus against the AWS environment, backdooring an S3 bucket policy, validating access/policy state, then reverting and cleaning up.*

**Components**
- Attacker zone: host with Stratus, Terraform, and AWS CLI.
- AWS environment: ephemeral S3 bucket and its bucket policy (optionally a test IAM role).
- Flow: verify baseline → detonate (attach malicious policy) → verify success → revert (remove policy) → cleanup (destroy infra).

---
### Minimal IAM Scope (example)

Use a role restricted to this technique in a non-production account. Adjust ARNs to your environment and add logging/assume-role as needed.


# Pre-reqs: Stratus, Terraform, AWS CLI; authenticated with least privilege.

# 1) Provision prerequisites (bucket, helpers)
stratus warmup aws.exfiltration.s3-backdoor-bucket-policy
stratus status aws.exfiltration.s3-backdoor-bucket-policy   # expect: WARM

# Set the technique bucket name shown in Stratus output:
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

<img width="800" height="368" alt="image" src="https://github.com/user-attachments/assets/0f0a1699-94a9-46f4-af87-c03e7413bbf2" />

Figure 2 — Technique reaches DETONATED and get-bucket-policy returns a policy JSON, confirming the malicious attachment and newly enabled access path.

<img width="800" height="254" alt="image" src="https://github.com/user-attachments/assets/16f02f5e-2eba-4125-9b15-e6c453763a97" />

Figure 3 — After stratus revert, status returns to WARM and get-bucket-policy yields NoSuchBucketPolicy, proving backdoor removal while keeping infra available.

<img width="800" height="169" alt="image" src="https://github.com/user-attachments/assets/14a3f2d4-ab81-4e69-ad4b-806b2d0245ec" />

Figure 4 — stratus cleanup destroys prerequisites via Terraform; status shows COLD, returning the environment to a production-safe state.

### What This Proves

- S3 access can be covertly enabled by bucket-policy manipulation without touching object data.
- Automated lifecycle prevents drift and guarantees safe rollback.
- Command-level checks provide clear before/after evidence for audit and learning.

### ATT&CK-Style Mapping (conceptual)

- T1567.002 — Exfiltration to Cloud Storage (exfiltration over web service)
- Related: control-plane abuse; defense evasion via policy changes

### Blue-Team Detection and Hardening

#### Detect
- CloudTrail: monitor `PutBucketPolicy`, `DeleteBucketPolicy`, `GetBucketPolicy`
- EventBridge: rules on bucket-policy creation/changes for sensitive buckets
- AWS Config: conformance rules for restrictive S3 policies
- Amazon Macie / DLP: alert on sensitive object access or movement

#### Prevent
- Least privilege for identities allowed to modify S3 bucket policies
- S3 Block Public Access and organization-level SCP guardrails
- Change-control workflows for policy edits on crown-jewel buckets
- Resource tagging and boundary policies to protect sensitive stores
