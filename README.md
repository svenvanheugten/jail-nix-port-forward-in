# jail-nix-port-forward-in

A [jail.nix](https://sr.ht/~alexdavid/jail.nix/) combinator that forwards a specific loopback port into the jail, without having to give it complete `network` access.

Usage:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.jail-nix.url = "sourcehut:~alexdavid/jail.nix";
  inputs.port-forward-in.url = "github:svenvanheugten/jail-nix-port-forward-in";

  outputs =
    {
      nixpkgs,
      jail-nix,
      port-forward-in,
      ...
    }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };

      jail = jail-nix.lib.extend {
        inherit pkgs;
        additionalCombinators = combinators: port-forward-in.lib { inherit pkgs combinators; };
      };
    in
    {
      packages.x86_64-linux.jailed = jail "my-jail" pkgs.hello (
        with jail.combinators;
        [
          # 127.0.0.1:8080 on the host becomes 127.0.0.1:8080 inside the jail
          (port-forward-in 8080)
        ]
      );
    };
}
```
