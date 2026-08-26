# Troubleshooting

Common failures and how to recover from them. The full log is at `~/fedora-setup.log` (or `$SETUP_LOG_FILE`); start there for the actual error message.

## A script failed mid-run

`setup.sh` doesn't write a marker file when a script fails, so it will be selected again on the next run. Two equivalent recovery paths:

```bash
# Option A — re-run the menu and pick the failed item again
bash setup.sh

# Option B — run the script directly (faster while iterating)
bash dev/node.sh
```

If a *successful* run set the wrong marker (e.g. you fixed an env var and want to re-run cleanly):

```bash
rm ~/.cache/fedora-setup/dev_node.sh.done
bash setup.sh
```

See [SETUP.md](SETUP.md) for how marker files map to script paths.

## Marker says done but the tool is broken or missing

Markers track *successful invocation*, not the current state of the system. If you uninstalled a tool manually, or a partial reinstall left it broken:

```bash
rm ~/.cache/fedora-setup/<category>_<name>.sh.done
bash <category>/<name>.sh
```

To wipe every marker and start fresh:

```bash
rm -rf ~/.cache/fedora-setup/
```

## `[[: not found` or `Bad substitution` when running a script

You ran the script with `sh` instead of `bash`. Every script has a re-exec shim that should catch this — if you still see the error, you're probably running an outdated copy. Always invoke with `bash` explicitly:

```bash
bash setup.sh         # ✅
bash dev/node.sh      # ✅
sh  dev/node.sh       # ❌ — relies on the shim
```

## Sudo prompt cancelled / timed out

The script exits non-zero, no marker is written, and the run loop continues with the next script. Re-run the cancelled one once you're ready:

```bash
sudo -v               # warm up the sudo cache for ~5 minutes
bash setup.sh         # answer the prompt promptly when asked
```

## GPG key generation hangs ("not enough random bytes")

[system/gpg.sh](../system/gpg.sh) uses `gpg --batch --generate-key` when `GIT_NAME` and `GIT_EMAIL` are set. On low-entropy systems (containers, freshly booted VMs), this can stall. Install an entropy daemon and retry:

```bash
sudo dnf install -y rng-tools
sudo systemctl enable --now rngd
bash system/gpg.sh
```

## Shell additions aren't picked up

Several scripts append blocks to `~/.zshrc` and `~/.bashrc` (NVM init, pyenv init, ssh-agent autostart, `GPG_TTY` export, Go/Cargo `PATH`). They take effect in **new** shells. Either:

```bash
source ~/.zshrc        # or ~/.bashrc
```

…or open a new terminal. Group changes (e.g. `docker` group from [dev/docker.sh](../dev/docker.sh)) need a full **log out and log back in**.

## DNF is busy or reports lock contention

DNF, PackageKit (GNOME Software), or the automatic update service may already
be running a transaction. Identify the owner and let it finish:

```bash
pgrep -af 'dnf|packagekitd'
sudo systemctl status packagekit.service dnf5-automatic.service
sudo journalctl -u packagekit.service -u dnf5-automatic.service --since '-10 min'
```

Do not delete DNF database/lock files or kill a transaction that is actively
writing RPM state. Once the other process exits, rerun the failed script.

## An RPM repository or signing-key check fails

Repository installers stop if a downloaded key does not have the exact pinned
primary fingerprint, if a repo URL is not HTTPS, or if DNF cannot validate an
RPM signature. Inspect the generated state without weakening the checks:

```bash
sudo dnf repolist --all
sudo sed -n '1,120p' /etc/yum.repos.d/<name>.repo
gpg --show-keys --fingerprint /etc/pki/rpm-gpg/RPM-GPG-KEY-<name>
```

Never work around this with `--nogpgcheck`, `gpgcheck=0`, or a key copied from
an unverified forum post. A vendor may have rotated its key or repository; check
the vendor's current official instructions and update the pinned fingerprint in
the script and migration ledger together.

## A script is blocked by SELinux

Keep SELinux enforcing and inspect the denial first:

```bash
getenforce
sudo ausearch -m AVC,USER_AVC -ts recent
sudo journalctl --since '-10 min' | grep -i 'avc:.*denied'
```

If the script wrote a normal system path with the wrong label, restore the
distribution policy label and retry:

```bash
sudo restorecon -Rv /path/written/by/the/script
```

Do not use `setenforce 0` as a permanent fix and do not feed arbitrary denials
straight into `audit2allow`. Confirm the expected file location and label first;
the relevant script should call `restorecon` when it owns a system path.

## firewalld is active but a service is unreachable

Check which zone the network interface actually uses and whether the required
service is present in that zone:

```bash
sudo systemctl status firewalld
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --get-default-zone
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --zone=public --query-service=ssh
```

Replace `public` with the active zone. `essentials/firewall.sh` preserves the
existing policy and enables only the standard `ssh` service; it does not open
custom application ports. Add any required port or service deliberately with
`firewall-cmd --permanent`, then reload firewalld.

## VirtualBox or VMware modules will not load under Secure Boot

Confirm Secure Boot state and the running kernel first:

```bash
mokutil --sb-state
uname -r
```

For the RPM Fusion VirtualBox path, enroll the akmods certificate exactly as
printed by `software/virtualbox.sh`, reboot, and complete **Enroll MOK** in the
firmware dialog:

```bash
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
# reboot and enroll the key, then:
mokutil --test-key /etc/pki/akmods/certs/public_key.der
sudo akmods --force --rebuild --kernels "$(uname -r)"
sudo modprobe vboxdrv
```

VMware's `vmmon` and `vmnet` modules are built outside Fedora/RPM Fusion and
must be signed after each rebuild with a key enrolled through MOK. Follow the
signing commands printed by `software/vmware.sh`; disabling Secure Boot is not
the repository's recovery path.

## A test verification fails

When `tests/run-script.sh` reports `❌ VERIFY FAILED`, the install ran but the post-check (manifest column or `tests/verify/<file>.sh`) didn't pass. Reproduce in isolation to read the full output:

```bash
bash tests/run-in-docker.sh 44 smoke <category>/<name>.sh
```

For idempotency-stage failures (`❌ STATE CHANGED ON RE-RUN`), the script wrote something different on the second invocation — usually a missing `grep -q` guard before appending to an rc file, or a duplicated install step.

## NVM / pyenv / cargo not found in a new shell

Check that the rc-file block was actually written:

```bash
grep -n NVM_DIR  ~/.zshrc
grep -n PYENV    ~/.zshrc
grep -n cargo    ~/.zshrc
```

If a block is missing, the script likely exited before the append step. Re-run with the marker removed (see above). If the block is present but nothing happens on shell start, your shell may be reading a different rc file (e.g. `~/.bash_profile` instead of `~/.bashrc`); add `source ~/.bashrc` to the relevant file.

## `setup.sh` reports "skipped" for an item I want to run

That item already has a marker. Either:

- Delete the marker (`rm ~/.cache/fedora-setup/<...>.done`) and re-run `setup.sh`, or
- Run the script directly with `bash <path>`, which ignores markers entirely.

## Still stuck

1. Tail the log: `tail -200 ~/fedora-setup.log`.
2. Run the failing script standalone and watch the live output.
3. Check the matching test in [tests/manifest.sh](../tests/manifest.sh) — the `compat` column flags scripts that aren't expected to work in certain environments (e.g. firewalld / GNOME / systemd inside a container).
