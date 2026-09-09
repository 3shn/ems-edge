# Security policy

## Scope

This project builds firmware images for industrial energy-management hardware
that runs unattended, on customer sites, for years. A defect here can reach a
device nobody can easily reboot. Treat that as the threat model.

## Reporting

Report privately through GitHub's **Report a vulnerability** button on the
Security tab, which opens a private advisory. Please do not open a public issue
for anything exploitable.

Useful in a report: what an attacker gains, what access they need first, and
the artefact and commit you observed it in. A proof of concept helps; a
description of the mechanism is enough to start.

## What is in scope

- Anything that lets an unsigned or altered artefact reach a device: the image
  build, signing, provisioning, and the update lanes.
- Per-device identity: key generation on-device, certificate issuance, and the
  northbound MQTT/TLS path.
- The CI supply chain — a workflow that would run untrusted code with a
  privileged credential is a vulnerability here, not a bug.

## What is out of scope

- Vulnerabilities in the vendor kernel or U-Boot themselves. Report those to
  the vendor and to upstream; open an issue here so the pin can be moved.
- The known posture of a given security tier. Keys on eMMC without OP-TEE is a
  documented tier, not a finding. If you can defeat the tier *above* the one a
  release claims, that is a finding.
