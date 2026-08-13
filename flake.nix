{
  description = "port-forward combinator for jail.nix";

  outputs = { ... }: {
    lib = import ./default.nix;
  };
}
