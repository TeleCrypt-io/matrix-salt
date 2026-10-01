# Copyright (c) 2014 Salt Stack Formulas
# Modified from the upstream source listed below.
# Licensed under the Apache License, Version 2.0; see ../LICENSES/Apache-2.0.txt and ../NOTICE.
"""Converge a unit in a named user's systemd manager.

Adapted from ``lkubb/salt-podman-formula`` at revision
``3e36dcc47f69992f518645c3c0858401e4cbcb6e``. See
``../NOTICE`` and ``../LICENSES/Apache-2.0.txt``.
"""

import time

from salt.exceptions import CommandExecutionError, SaltInvocationError


def running(name, user=None, timeout=10):
    """Ensure the named user service is active.

    When inactive, reload the user's unit definitions before queuing a start.
    ``timeout`` bounds the state-side wait for the queued systemd job.
    """
    ret = {"name": name, "changes": {}, "result": True, "comment": ""}
    try:
        timeout = _timeout(timeout)
        if not user:
            raise SaltInvocationError("user_service.running requires a user.")
        if __salt__["user_service.is_running"](name, user=user):
            ret["comment"] = f"Service {name} is already running for {user}."
            return ret

        if __opts__["test"]:
            ret["result"] = None
            ret["changes"]["started"] = name
            ret["comment"] = f"Service {name} would be started for {user}."
            return ret

        # Quadlet-generated user units appear after daemon-reload. Reload only
        # on the path that will actually start an inactive service.
        __salt__["user_service.daemon_reload"](user=user)
        __salt__["user_service.start"](name, user=user)
        ret["changes"]["started"] = name

        deadline = time.monotonic() + timeout
        while not __salt__["user_service.is_running"](name, user=user):
            if time.monotonic() >= deadline:
                ret["result"] = False
                ret["comment"] = f"Service {name} did not become active within {timeout:g}s."
                return ret
            time.sleep(0.2)

        ret["comment"] = f"Service {name} was started for {user}."
    except (CommandExecutionError, SaltInvocationError, ValueError) as exc:
        ret["result"] = False
        ret["comment"] = str(exc)
    return ret


def dead(name, user=None, timeout=10):
    """Ensure the named user service is inactive.

    This state supports Salt's test-mode result so it can be used as a
    ``prereq`` before changing a service's unit or configuration files.
    """
    ret = {"name": name, "changes": {}, "result": True, "comment": ""}
    try:
        timeout = _timeout(timeout)
        if not user:
            raise SaltInvocationError("user_service.dead requires a user.")
        if __salt__["user_service.is_stopped"](name, user=user):
            ret["comment"] = f"Service {name} is already stopped for {user}."
            return ret

        if __opts__["test"]:
            ret["result"] = None
            ret["changes"]["stopped"] = name
            ret["comment"] = f"Service {name} would be stopped for {user}."
            return ret

        __salt__["user_service.stop"](name, user=user)
        ret["changes"]["stopped"] = name

        deadline = time.monotonic() + timeout
        while not __salt__["user_service.is_stopped"](name, user=user):
            if time.monotonic() >= deadline:
                ret["result"] = False
                ret["comment"] = f"Service {name} did not stop within {timeout:g}s."
                return ret
            time.sleep(0.2)

        ret["comment"] = f"Service {name} was stopped for {user}."
    except (CommandExecutionError, SaltInvocationError, ValueError) as exc:
        ret["result"] = False
        ret["comment"] = str(exc)
    return ret


def _timeout(value):
    try:
        timeout = float(value)
    except (TypeError, ValueError) as exc:
        raise SaltInvocationError("timeout must be a non-negative number.") from exc
    if timeout < 0:
        raise SaltInvocationError("timeout must be a non-negative number.")
    return timeout
