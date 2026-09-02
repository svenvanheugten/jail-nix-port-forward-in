{ pkgs, combinators }:

with combinators;

let
  inherit (pkgs.lib) getExe getExe';
  socat = getExe pkgs.socat;
  mktemp = getExe' pkgs.coreutils "mktemp";
  rm = getExe' pkgs.coreutils "rm";
  sleep = getExe' pkgs.coreutils "sleep";
  seq = getExe' pkgs.coreutils "seq";

  # How many connections the jail may hold open through the forwarder at once.
  # We need to cap this because every connection spawns a socat process on the
  # host.
  maxConnections = 128;
in
{
  port-forward-in =
    port':
    let
      port =
        if pkgs.lib.isInt port' && port' >= 1024 && port' < 65536 then
          toString port'
        else if pkgs.lib.isInt port' && port' > 0 && port' < 1024 then
          throw ''
            port-forward-in ${toString port'}: privileged ports are not supported.

            The forwarder listens on the same port number inside the jail, and the
            jail has no CAP_NET_BIND_SERVICE, so binding ${toString port'} there
            would fail at runtime. Use a port in 1024..65535.
          ''
        else
          throw "port-forward-in: expected an integer TCP port in 1024..65535, got ${
            pkgs.lib.generators.toPretty { } port'
          }";
      sock = "/run/lo-fwd-${port}.sock";
      hostDir = "LO_FWD_${port}_DIR";
      hostPid = "LO_FWD_${port}_PID";
    in
    include-once "port-forward-in-${port}" (compose [

      (defer (
        state:
        if state.namespaces.net or false then
          throw ''
            port-forward-in ${port} cannot be combined with the `network` combinator.

            Sharing the host's network namespace turns the forwarder into an unbounded
            connect loop. With `network` the jail can already reach 127.0.0.1:${port}
            directly, so drop `port-forward-in ${port}`.
          ''
        else
          state
      ))

      (add-runtime ''
        ${hostDir}=$(${mktemp} -d)
        ${socat} UNIX-LISTEN:"''$${hostDir}/sock",fork,max-children=${toString maxConnections},mode=600 TCP:127.0.0.1:${port} >/dev/null 2>&1 &
        ${hostPid}=$!
        for _ in $(${seq} 100); do
          [ -S "''$${hostDir}/sock" ] && break
          ${sleep} 0.1
        done
        RUNTIME_ARGS+=(--ro-bind "''$${hostDir}/sock" ${sock})
      '')

      (add-cleanup ''
        kill "''${${hostPid}-}" 2>/dev/null || true
        ${rm} -rf "''${${hostDir}-}"
      '')

      (wrap-entry (entry: ''
        ${socat} TCP-LISTEN:${port},bind=127.0.0.1,reuseaddr,fork UNIX-CONNECT:${sock} >/dev/null 2>&1 &
        jail_pid=$!
        trap 'kill "$jail_pid" 2>/dev/null || true' EXIT
        ${entry}
      ''))
    ]);
}
