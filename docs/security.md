# Publication and operational security

This is a **sanitized portfolio project**. The source reference materials contained organization-specific hostnames, private network addresses and proxy settings; those are **deliberately omitted** from this repository. Placeholder addresses `192.168.50.10` to `.12` are not the actual hosts.

No real SSH keys, authorization tokens, usernames, passwords, model binaries, chat records, institution-specific hostnames or service configuration files have been copied into the public-facing code.

## Before using any script

- Use your own computers and a network you administer or have explicit permission to use.
- Do not publish unauthenticated FastAPI, Ray, RPC or `llama-server` ports on the Internet.
- Protect local services with firewalls, authentication and HTTPS at a trusted reverse proxy before broader deployment.
- Never commit `.env`, `nodes.json`, `models/`, private keys or credentials.
- The experimental RPC script can modify systemd configuration and run root-level commands. Treat it as an **unreviewed legacy experiment**, not a copy-and-paste production installer.
- Review software licenses and model use terms before distributing binaries or model weights. None are bundled here.
