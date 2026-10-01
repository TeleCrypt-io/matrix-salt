# Copyright (c) 2014 Salt Stack Formulas
# Modified from the upstream source listed below.
# Licensed under the Apache License, Version 2.0; see ../LICENSES/Apache-2.0.txt and ../NOTICE.
"""Execution functions for a named user's systemd manager.

Adapted from ``lkubb/salt-podman-formula`` at revision
``3e36dcc47f69992f518645c3c0858401e4cbcb6e``. See
``../NOTICE`` and ``../LICENSES/Apache-2.0.txt``.
"""

from pathlib import Path

from salt.exceptions import CommandExecutionError, SaltInvocationError

__virtualname__ = "user_service"


def __virtual__():
    """Load on Linux hosts booted with systemd."""
    if __grains__.get("kernel") == "Linux":
        return __virtualname__
    return False, "user_service is available only on Linux."


def is_running(name, user=None):
    """Return whether ``name`` is active in ``user``'s systemd manager."""
    result = _systemctl("is-active", name, user=user, ignore_retcode=True)
    if result["retcode"] in (0, 3, 4):
        return result["retcode"] == 0
    raise CommandExecutionError(
        f"Could not query user service {name}: {result['stderr'] or result['stdout']}"
    )


def is_stopped(name, user=None):
    """Return true only after shutdown has finished, never while deactivating."""
    result = _systemctl("is-active", name, user=user, ignore_retcode=True)
    if result["retcode"] in (0, 3, 4):
        return result["stdout"].strip() in ("inactive", "failed", "unknown")
    raise CommandExecutionError(
        f"Could not query user service {name}: {result['stderr'] or result['stdout']}"
    )


def start(name, user=None):
    """Queue a start for ``name`` in ``user``'s systemd manager."""
    _systemctl("start", name, user=user, no_block=True)
    return True


def stop(name, user=None):
    """Queue a stop for ``name`` in ``user``'s systemd manager."""
    _systemctl("stop", name, user=user, no_block=True)
    return True


def daemon_reload(user=None):
    """Reload ``user``'s unit definitions."""
    _systemctl("daemon-reload", user=user)
    return True


def _systemctl(command, name=None, user=None, no_block=False, ignore_retcode=False):
    if not user:
        raise SaltInvocationError("user_service requires an explicit user account.")

    user_info = __salt__["user.info"](user)
    if not user_info or user_info.get("uid") is None:
        raise SaltInvocationError(f"Could not find user '{user}'.")

    runtime_dir = Path(f"/run/user/{user_info['uid']}")
    bus = runtime_dir / "bus"
    if not bus.exists():
        raise CommandExecutionError(
            f"User manager for {user} is unavailable at {bus}; ensure the user manager is running."
        )

    argv = ["systemctl", "--user"]
    if no_block:
        argv.append("--no-block")
    argv.append(command)
    if name is not None:
        # Keep unit names as a single argv item and prevent option interpretation.
        argv.extend(("--", str(name)))

    result = __salt__["cmd.run_all"](
        argv,
        runas=user,
        env={
            "XDG_RUNTIME_DIR": str(runtime_dir),
            "DBUS_SESSION_BUS_ADDRESS": f"unix:path={bus}",
        },
        python_shell=False,
        ignore_retcode=ignore_retcode,
        output_loglevel="quiet",
    )
    if not ignore_retcode and result["retcode"]:
        raise CommandExecutionError(
            f"systemctl --user {command} failed for {name or user}: "
            f"{result['stderr'] or result['stdout']}"
        )
    return result
