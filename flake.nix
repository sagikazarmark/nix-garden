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
              # self'.packages.garden-src
            ];

            # https://github.com/cachix/devenv/issues/528#issuecomment-1556108767
            containers = pkgs.lib.mkForce { };
          };

          ci = devenv.shells.default;
        };

        packages = {
          garden-src = pkgs.mkYarnPackage rec {
            name = "garden";
            version = "0.13.13";

            src = pkgs.fetchFromGitHub {
              owner = "garden-io";
              repo = "${name}";
              rev = "${version}";
              sha256 = "sha256-IDdZ+UpFoycX00TK99JTSTqX9xUzYSYAuhZK5DPDzRg=";
            };

            patches = [ ./remove_self_update.patch ];

            buildPhase = ''
              runHook preBuild

              export HOME=$(mktemp -d)
              yarn --offline build
              # yarn build

              # pushd deps/${name}
              # yarn --verbose build
              # popd

              runHook postBuild
            '';

            # installPhase = ''
            #   runHook preInstall
            #
            #
            #   runHook postInstall
            # '';

            doDist = false;
          };

          garden = pkgs.stdenv.mkDerivation rec {
            pname = "garden";
            version = "0.13.13";

            src =
              let
                selectSystem = attrs: attrs.${system} or (throw "Unsupported system: ${system}");

                suffix = selectSystem {
                  x86_64-linux = "linux-amd64";
                  x86_64-darwin = "macos-amd64";
                  aarch64-linux = "linux-arm64";
                  aarch64-darwin = "macos-arm64";
                };
                sha256 = selectSystem {
                  x86_64-linux = "sha256-PV1qZI29AsdwpKSjQxgupJzV8T32/FlNFrFgM1gO92A=";
                  x86_64-darwin = "sha256-Jpywk3BI01YAKDaPJBdatpRrEB5/HMzBBgN1BoTpqmA=";
                  aarch64-linux = "sha256-n787e9fOpmZs1cGgJHwkodmYQRNclaSnOQo8OGpX1nQ=";
                  aarch64-darwin = "sha256-XJSL+RafzSZ+0jIepgJL1Sl2hsTumAd9JHVAzDIOKEw=";
                };
              in
              pkgs.fetchzip {
                inherit sha256;

                url = "https://github.com/garden-io/garden/releases/download/${version}/garden-${version}-${suffix}.tar.gz";
              };

            # buildInputs = [ pkgs.git ];
            nativeBuildInputs = [ pkgs.git pkgs.makeWrapper ];

            dontConfigure = true;
            dontBuild = true;
            dontFixup = true;
            dontStrip = true;
            dontPatchELF = true;

            installPhase = ''
              runHook preInstall

              mkdir -p $out/opt/garden/
              cp -r * $out/opt/garden/
              cd $out/opt/garden/static && git init && cd -

              runHook postInstall
            '';

            # https://github.com/kubernetes/test-infra/issues/28721#issuecomment-1429813787
            postInstall = ''
              mkdir -p $out/bin/
              makeWrapper $out/opt/garden/garden $out/bin/garden \
                --set GIT_CONFIG_COUNT 1 \
                --set GIT_CONFIG_KEY_0 safe.directory \
                --set GIT_CONFIG_VALUE_0 $out/opt/garden/static
            '';
          };
        };
      };
    };
}
