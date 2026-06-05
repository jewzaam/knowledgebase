# Rootless Podman Networking

Verified: 2026-06-03  
Provenance: <https://github.com/NVIDIA/OpenShell>

Rootless podman uses pasta (from the passt project) to provide network namespace connectivity without requiring root privileges. Pasta translates between L2/L3 in the rootless network namespace and L4 sockets on the host.

## Pasta Version Compatibility

`passt-0^20260120.g386b5f5` (Fedora 43 updates repo) breaks `host-gateway` (169.254.1.2) reachability from bridge-networked containers in rootless mode. The older `passt-0^20250919.g623dbf6` (Fedora 43 release repo) works correctly.

Symptom: ping to 169.254.1.2 from a bridge-networked container returns 100% packet loss. Default network (pasta-direct, no bridge) still works.

Fix: downgrade pasta and recreate the rootless-netns:

```bash
sudo dnf downgrade passt-0^20250919.g623dbf6-1.fc43
# Kill running pasta process
pkill pasta
# Remove rootless-netns so podman recreates it
rm -rf /run/user/$(id -u)/containers/networks/rootless-netns/
```

## TAP vs Interface-Copy Mode

Pasta's `--config-net` behaves differently depending on host interface count:

- **Single-NIC hosts** (e.g., VM with only enp1s0): pasta copies the real interface into the rootless-netns with the host's real IP.
- **Multi-NIC hosts** (e.g., workstation with wifi + ethernet + docker0 + virbr0): pasta creates a `tap0` interface at `169.254.2.1/16` instead.

TAP mode causes bridge-to-host traffic failure. Netavark's POSTROUTING masquerade rewrites the source to `169.254.2.1` (tap0's IP), resulting in both src and dst being in the 169.254.0.0/16 link-local range. Pasta cannot handle this correctly.

Check the mode by inspecting `/run/user/<uid>/containers/networks/rootless-netns/info.json`:

- TAP mode: `"IPAddresses": ["169.254.2.1"]`
- Interface-copy mode: `"IPAddresses": ["<real_ip>"]`

## Rootless-netns Debugging

The rootless-netns is where bridge interfaces and pasta's TAP/copied interface coexist. To inspect it:

```bash
podman unshare nsenter --net=/run/user/$(id -u)/containers/networks/rootless-netns/rootless-netns <command>
```

Useful commands inside the rootless-netns:

```bash
ip link show
ip addr
ip route
ip neigh
nft list ruleset
cat /proc/sys/net/ipv4/ip_forward
```

**Important**: do NOT use `nsenter -n -t <pasta_pid>`. Pasta runs in the HOST network namespace, so entering its netns shows the host's interfaces, not the rootless-netns.

## Bridge Networking Data Path

Container (10.89.x.y) → eth0 → bridge gateway (10.89.x.1 on podmanN interface) → rootless-netns kernel IP forwarding → netavark nftables FORWARD chain (accepts traffic from bridge subnets) → netavark POSTROUTING masquerade (rewrites src to outgoing interface IP) → tap0 or copied interface → pasta L2-to-L4 translation → host TCP/UDP sockets.

The masquerade step is critical:

- If the outgoing interface is tap0 (169.254.2.1), the masqueraded source is link-local, which breaks pasta.
- If it's a copied real interface (e.g., 192.168.x.x), the source is routable and pasta handles it correctly.

## Docker and Rootless Podman Isolation

Docker iptables rules do NOT interfere with rootless podman. Tested by stopping Docker, flushing DOCKER-* iptables chains, setting FORWARD policy to ACCEPT, and disabling firewalld. Rootless podman bridge networking failure persisted through all of these changes. The issue is internal to the rootless-netns (pasta TAP mode), not in the host's firewall rules.

## Network Interface Switch Invalidates Rootless-netns

When the host switches network interfaces (e.g., wired ethernet to wifi, or vice versa), existing rootless podman bridge networking breaks silently. Containers may show as running and even report healthy, but the supervisor/application inside cannot reach the host because pasta's rootless-netns was configured for the previous interface.

The rootless-netns retains the old interface configuration (routes, ARP, pasta TAP/copied interface) and does not auto-detect the switch.

Symptom: sandboxes show "Ready" phase but connections time out or fail with "failed to connect."

Fix: kill the pasta process, remove the rootless-netns directory, restart podman socket, then restart containers. Podman recreates the rootless-netns with the current active interface on the next container start.

```bash
kill $(cat /run/user/$(id -u)/containers/networks/rootless-netns/rootless-netns-conn.pid)
rm -rf /run/user/$(id -u)/containers/networks/rootless-netns/
systemctl --user restart podman.socket
podman start <container_name>
```

## Libvirt VM Networking with Docker

Docker's iptables rules block libvirt VM traffic on virbr0. Fix:

```bash
sudo iptables -I FORWARD 1 -i virbr0 -j ACCEPT
sudo iptables -I FORWARD 2 -o virbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t nat -A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -j MASQUERADE
sudo firewall-cmd --zone=libvirt --add-masquerade
sudo firewall-cmd --zone=FedoraWorkstation --add-masquerade
```

These rules must be re-applied after every Docker restart or system reboot.

## OpenShell Sandbox JWT Expiry

OpenShell sandbox containers authenticate to the gateway using a JWT minted at creation time with a 1-hour TTL (`ttl_secs=3600` in gateway config). After a gateway restart or when more than 1 hour has elapsed, the token expires. The supervisor inside the container fails with `Unauthenticated: invalid token: ExpiredSignature` and exits after 5 retries, killing the container.

The token is bind-mounted from `~/.local/state/openshell/podman-sandbox-tokens/<sandbox-id>/sandbox.jwt` on the host.

Re-minting is possible: the gateway's Ed25519 signing key lives at `.cache/gateway-podman/tls/jwt/signing.pem` (dev mode). The JWT claims structure requires: `sub` (SPIFFE URI `spiffe://openshell/sandbox/<uuid>`), `iss` and `aud` (both `openshell-gateway:<gateway_id>`), `iat`, `exp`, and crucially `sandbox_id` (the UUID denormalized from sub — missing this field causes `missing field sandbox_id` validation error).

The gateway has a `RefreshSandboxToken` RPC for token renewal, but it requires a valid (non-expired) token to authenticate the request — chicken-and-egg when the token is already expired. No CLI command exists to re-mint tokens. Writing a fresh token to the bind-mounted host file and restarting the container is the current workaround.

Signing keys are preserved across `mise run gateway` restarts (`generate-certs` skips if PKI files already exist), so re-minted tokens using the same signing key are valid. But the TTL makes any sandbox token stale after 1 hour regardless.
