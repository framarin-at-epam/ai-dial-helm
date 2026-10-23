# Post-mortem: ROSA preflight egress failure in `vpc-00a8a9ecd27356a26`

**Date:** 2026-10-23
**AWS account:** 354363695108
**Region:** us-east-2
**Cluster type:** ROSA Classic (`platform: aws-classic`)
**Status:** Resolved — `rosa verify network` passed, cluster is active

---

## Summary

A ROSA cluster failed its preflight network verification. The Red Hat network verifier
reported that eighteen Red Hat and AWS endpoints were unreachable from subnet
`subnet-01f5eb7753f6b69fe`, and presented the failure as a firewall allowlist problem,
recommending that the URLs be added to "the allowlist of these subnet firewalls."

No firewall was involved. The subnet's route table contained a route intended as the
default gateway, entered as `0.0.0.0/8` instead of `0.0.0.0/0`, pointing at NAT gateway
`nat-15b9e57a9cdd14075`. A `/8` prefix covers only `0.0.0.0`–`0.255.255.255`, reserved
address space that no real traffic is ever destined for, so the route matched nothing.
The subnet consequently had no default route at all and every internet-bound packet was
dropped for want of a path. The defect was a single character.

The same investigation revealed that three of the four private subnets in the VPC had no
default route whatsoever — not a typo, simply nothing — and would have failed identically
had the cluster been asked to place nodes in them.

---

## Impact

Cluster provisioning was blocked at preflight. No workload impact, as the cluster had
never reached a running state. Diagnosis consumed significantly more time than the fix
because the error message pointed at the wrong subsystem.

---

## Root cause

The VPC was built by hand in the AWS console. While adding the default route to the
private subnet's route table, `0.0.0.0/8` was entered in the destination field instead of
`0.0.0.0/0`, most likely a keystroke slip.

Nothing in the platform was positioned to catch it. `0.0.0.0/8` is a syntactically valid
CIDR block and is already in canonical form, since `0.0.0.0` is the correct network
address for a `/8`. The console's validator therefore had no objection. Had a
non-canonical value such as `10.0.5.3/8` been entered, AWS would have flagged or
normalised it, but an all-zeros address with the wrong prefix length passes silently. The
console validates the form of the input, never the intent, and has no concept that the
operator was attempting to create a default route. It also does not warn that a
newly added route is unreachable or inert.

Everything else in the VPC was configured correctly. The NAT gateway was `available`,
of `ConnectivityType: public`, held elastic IP `3.XXX.93.YY`, and sat behind a public
subnet with a valid internet gateway route. There was no disconnected NAT and no
security group or network ACL defect.

---

## Why this was hard to diagnose

Three separate signals pointed away from the real cause.

**DNS kept working throughout.** Every hostname resolved correctly during testing, which
reads as evidence of a healthy network but proves nothing. The Route 53 VPC resolver sits
at a link-local address inside the VPC and requires no internet egress whatsoever. Clean
name resolution is compatible with total egress failure.

**The S3 gateway endpoint kept working.** Route `pl-7ba54012` via `vpce-0ca7a413b910c3aa3`
remained functional for the same reason — gateway endpoints are reached without leaving
the VPC. This made the subnet look partially connected.

**The error message prescribed a fix for an unestablished cause.** The verifier had
everything needed to diagnose this correctly: it knew DNS resolved, it knew the TCP
connections timed out rather than being refused or failing TLS negotiation, and it knew
that every endpoint failed rather than a subset. From those facts, "this subnet has no
egress path, check the route table" follows mechanically. Instead the message recommended
an allowlist change and linked to the egress requirements documentation, which is an
accurate document about a different problem.

**The decisive signal was the failure pattern, not the failure itself.** A genuinely
mis-tuned domain allowlist blocks some endpoints and permits others. All eighteen failing
at once means there is no path out at all. Check for a real `0.0.0.0/0` route before
touching firewall rules.

---

## Diagnostic path that worked

An EC2 probe instance was launched directly into the affected subnet with the test passed
as user-data, writing results to the serial console. This avoided any dependency on SSH or
SSM, both of which were themselves unreachable in a subnet with no egress. Results were
retrieved with `aws ec2 get-console-output --latest`.

The probe established that DNS resolved but all connections timed out with `http 000`,
including `sts.us-east-2.amazonaws.com` over plain IPv4. That ruled out resolution,
DHCP option sets, IPv6 preference, and domain-based filtering, and narrowed the cause to
routing. Inspecting the route table then exposed the `0.0.0.0/8` entry directly.

---

## Environment

| Name | Subnet | AZ | CIDR | Route table | Egress |
|---|---|---|---|---|---|
| private1-us-east-2a | `subnet-08e70e2e1a08aeed5` | us-east-2a | 10.0.128.0/20 | `rtb-0f4841ab3c2aa9c0b` | none → NAT (fixed) |
| private2-us-east-2b | `subnet-0ceed2392bdea76f8` | us-east-2b | 10.0.144.0/20 | `rtb-069ac6a4902a1fbb8` | none → NAT (fixed) |
| private3-us-east-2a | `subnet-089f7f9ebf7216872` | us-east-2a | 10.0.160.0/20 | `rtb-061150ff77c7c2e14` | none → NAT (fixed) |
| private4-us-east-2b | `subnet-01f5eb7753f6b69fe` | us-east-2b | 10.0.176.0/20 | `rtb-065ce5cdd21a5af53` | `0.0.0.0/8` → NAT (fixed) |
| public1-us-east-2a | `subnet-0d096ff42976a3a89` | us-east-2a | 10.0.0.0/20 | `rtb-069acf815e90818e8` | IGW `igw-04c95a2f788d54a5c` |
| public2-us-east-2b | `subnet-026033a5a48444e08` | us-east-2b | 10.0.16.0/20 | `rtb-069acf815e90818e8` | IGW `igw-04c95a2f788d54a5c` |

Route table `rtb-0a737f594ea5986c9` has no subnet associations and no default route. It is
most likely the VPC main route table, which means any subnet created later without an
explicit association will silently inherit a dead end.

The VPC spans only two availability zones. Multi-AZ ROSA Classic requires three, so this
VPC supports a single-AZ cluster only as currently built.

---

## Remediation applied

```bash
export AWS_PAGER=""

# Replace the malformed default route on the affected subnet
aws ec2 create-route --region us-east-2 --route-table-id rtb-065ce5cdd21a5af53 \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id nat-15b9e57a9cdd14075

aws ec2 delete-route --region us-east-2 --route-table-id rtb-065ce5cdd21a5af53 \
  --destination-cidr-block 0.0.0.0/8

# Add the missing default route to the three remaining private subnets
for RTB in rtb-061150ff77c7c2e14 rtb-069ac6a4902a1fbb8 rtb-0f4841ab3c2aa9c0b;
  aws ec2 create-route --region us-east-2 --route-table-id "$RTB" \
    --destination-cidr-block 0.0.0.0/0 --nat-gateway-id nat-15b9e57a9cdd14075;
end
```

Verified with `rosa verify network --subnet-ids subnet-01f5eb7753f6b69fe --region us-east-2
--role-arn <installer-role>`, which passed. Note that in subnet mode, outside any cluster
context, `rosa verify network` requires `--role-arn`; use `rosa list account-roles` to find
the installer role ARN, or `rosa verify network --cluster <name>` to skip it.

---

## Not a documentation or defaults problem

Worth stating explicitly, since the question arose: no AWS default, provisioning template,
or documented procedure produces `0.0.0.0/8`. The CloudFormation template behind
`rosa create network`, Red Hat's Terraform modules, and the manual steps in the ROSA
documentation all specify `0.0.0.0/0` for private subnet egress. The value had to be typed
by hand.

The gap is in guardrails rather than guidance. AWS offers no built-in check for a subnet
with no viable default route, and nothing in either provisioning flow suggests running
Reachability Analyzer, which would have found this in seconds. Red Hat's verifier has the
data to diagnose it and does not.

Also worth noting for anyone reading the original diagnostic output: the load balancer
hostnames that appeared during DNS resolution — `...us-east-1.elb.amazonaws.com` for
`api.openshift.com` and `registry-proxy-134442355.us-east-1.elb.amazonaws.com` for
`registry.redhat.io` — are Red Hat's own infrastructure in Red Hat's account. No load
balancer in this AWS account was involved in the failure.

---

## Outstanding items

If this VPC is ever reconciled against Terraform or CloudFormation, the `0.0.0.0/8` value
must be corrected in source, or the next apply will silently reintroduce the outage.

There is a single NAT gateway, located in us-east-2b. Both us-east-2a private subnets now
route through it, incurring cross-AZ data transfer charges on every image pull and creating
a hard dependency on one availability zone. A second NAT gateway in `public1-us-east-2a` is
the cleaner build if this moves toward production.

Both subnets named "public" have auto-assign public IPv4 disabled. This is harmless for the
NAT gateway, which holds an elastic IP, and for load balancers, but is surprising given the
naming and worth reviewing before provisioning public-facing services.

---

## Prevention

Run this before handing any VPC to a cluster installer. It lists every route table in the
VPC lacking a real default route, and would have printed four lines before the ROSA console
was ever opened.

```bash
aws ec2 describe-route-tables --region us-east-2 \
  --filters Name=vpc-id,Values=vpc-00a8a9ecd27356a26 \
  --query 'RouteTables[?length(Routes[?DestinationCidrBlock==`0.0.0.0/0`])==`0`].{RTB:RouteTableId,Subnets:Associations[].SubnetId}'
```

To catch near-miss prefixes specifically — a gateway target on any `0.0.0.0/N` where N is
not zero is almost always a typo:

```bash
aws ec2 describe-route-tables --region us-east-2 \
  --filters Name=vpc-id,Values=vpc-00a8a9ecd27356a26 \
  --query 'RouteTables[].Routes[?starts_with(to_string(DestinationCidrBlock), `"0.0.0.0/"`) && DestinationCidrBlock != `0.0.0.0/0`]'
```

Two habits reduce the chance of recurrence: prefer `rosa create network` over the console
when building cluster VPCs, since it is CloudFormation-backed and removes hand-typed CIDRs
from the process; and run VPC Reachability Analyzer against one private subnet as a
pre-install check.

---

## Appendix: reusable egress probe

Launches a throwaway instance in a target subnet and writes connectivity results to the
serial console, requiring no SSH, no SSM, and no working egress. Costs well under one cent.

```bash
cat > /tmp/probe.sh <<'EOF'
#!/bin/bash
exec > /dev/console 2>&1
echo "=== PROBE START ==="
ip -br addr
echo "v4 default: $(ip -4 route show default)"
echo "v6 default: $(ip -6 route show default)"
for h in quay.io registry.redhat.io sts.us-east-2.amazonaws.com; do
  echo "$h v4 -> $(curl -4 -s -o /dev/null -w '%{http_code}' --max-time 8 https://$h/ || echo FAIL)"
  echo "$h v6 -> $(curl -6 -s -o /dev/null -w '%{http_code}' --max-time 8 https://$h/ || echo FAIL)"
done
echo "=== PROBE DONE ==="
EOF

aws ec2 run-instances --region us-east-2 \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro --subnet-id <TARGET_SUBNET> \
  --user-data file:///tmp/probe.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=egress-probe}]'

# wait 3-5 minutes for the serial console buffer to populate
aws ec2 get-console-output --region us-east-2 --latest --output text \
  --instance-id <INSTANCE_ID> | sed -n '/PROBE START/,/PROBE DONE/p'

aws ec2 terminate-instances --region us-east-2 --instance-ids <INSTANCE_ID>
```

Interpreting results: `200` is a clear pass, while `404` from `registry.redhat.io` and `302`
from `sts` are also passes — they prove TLS completed and a real HTTP response returned.
`000` with a timeout means packets are being dropped, pointing at routing, a network ACL,
or a security group. A TLS error rather than a timeout is the signature of SNI-based
filtering, which is the only case where a domain allowlist is genuinely the problem.
`v6 -> FAIL` is expected and harmless on an IPv4-only subnet.

Three operational notes. The `--latest` flag is required for `get-console-output` on
Nitro-based instances such as `t3`. On Windows with Git Bash, set `export AWS_PAGER=""` or
captured output arrives garbled with pager control text. And watch for CRLF line endings in
the user-data script, which break the shebang silently and cause cloud-init to run nothing
at all.
