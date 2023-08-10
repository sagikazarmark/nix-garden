# Nix flake for [Garden](https://garden.io)

[![built with nix](https://img.shields.io/badge/builtwith-nix-7d81f7?style=flat-square)](https://builtwithnix.org)

This is a flake for installing Garden from its [binary distribution channel](https://github.com/garden-io/garden/releases/tag/0.13.10).

I'm working on a more "native" installation method (tracked in [this](https://github.com/garden-io/garden/issues/4935) issue) and hope to submit the results in nixpkgs.

## Usage

```nix
{
  description = "Your flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    garden.url = "github:sagikazarmark/nix-garden";
  };

  outputs = { self, nixpkgs, flake-utils, garden, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShell = pkgs.mkShell {
          buildInputs = [ garden.packages.${system}.garden ];
        };
      });
}
```

## License

The project is licensed under the [MIT License](LICENSE).
