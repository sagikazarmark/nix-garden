{
  description = "Automation for Kubernetes development and testing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
      ];

      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { config, self', inputs', pkgs, system, ... }: rec {
        devenv.shells = {
          default = {
            packages = with pkgs; [
              kind
              kubectl
              kustomize
            ] ++ [
              self'.packages.garden
            ];

            # https://github.com/cachix/devenv/issues/528#issuecomment-1556108767
            containers = pkgs.lib.mkForce { };
          };

          ci = devenv.shells.default;
        };

        packages = {
          # garden = pkgs.mkYarnPackage rec {
          #   name = "garden";
          #   version = "0.13.10";
          #
          #   src = pkgs.fetchFromGitHub {
          #     owner = "garden-io";
          #     repo = "${name}";
          #     rev = "${version}";
          #     sha256 = "sha256-rsY1Hypp3rTjwRu9/whmz4WtXn1ZmUgEAJgqnoCe3Rk=";
          #   };
          # };
          garden = pkgs.stdenv.mkDerivation rec {
            pname = "garden";
            version = "0.13.10";

            src =
              let
                selectSystem = attrs: attrs.${system} or (throw "Unsupported system: ${system}");

                suffix = selectSystem {
                  x86_64-linux = "linux-amd64";
                  x86_64-darwin = "macos-amd64";
                  aarch64-darwin = "macos-amd64";
                };
                sha256 = selectSystem {
                  x86_64-linux = "sha256-bgjjbI4px2NlkSxMhXZhXWUqaZghf16dlx7Y18N9ujs=";
                  x86_64-darwin = "sha256-3/rYexkO7nDN9nmX2g3rER+HWhMXx0Vi9jQ8brbacBM=";
                  aarch64-darwin = "sha256-3/rYexkO7nDN9nmX2g3rER+HWhMXx0Vi9jQ8brbacBM=";
                };
              in
              pkgs.fetchzip {
                inherit sha256;

                url = "https://github.com/garden-io/garden/releases/download/${version}/garden-${version}-${suffix}.tar.gz";
              };

            buildInputs = [ pkgs.git ];

            dontConfigure = true;
            dontBuild = true;
            dontFixup = true;
            dontStrip = true;
            dontPatchELF = true;

            installPhase = ''
              runHook preInstall
              mkdir -p $out/
              cp -r * $out/
              cd $out/static && git init
              mkdir -p $out/bin/
              ln -s $out/garden $out/bin/garden
              runHook postInstall
            '';
          };
        };
      };
    };
}
