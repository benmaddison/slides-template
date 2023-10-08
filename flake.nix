{
  description = "Template repository for slides using nix and marp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    nix-marp = {
      url = "github:tweag/nix-marp";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, ... } @ inputs:
    let
      lib = inputs.nixpkgs.lib;
      code = _: s: s;
    in
    {
      templates.default = {
        path = ./template;
        description = "slide deck template";
      };
      lib = {
        systems = [ "x86_64-linux" ];
        mkLib = pkgs:
          let
            inherit (pkgs) system;
            marp-cli = pkgs.writeShellApplication {
              name = "marp";
              text = code "bash" ''
                export CHROME_PATH="${pkgs.ungoogled-chromium}/bin/chromium"
                ${inputs.nix-marp.packages.${system}.marp-cli}/bin/marp "$@"
              '';
            };
            build = { src, outFormat, assetPaths }:
              pkgs.runCommand "build-${outFormat}-slides" { } (code "bash" ''
                mkdir -p $out
                ${lib.concatMapStrings (path: code "bash" ''
                  cp -R "${src}/${path}" "$out/"
                '') assetPaths}
                tmphome="$(${pkgs.coreutils}/bin/mktemp -d)"
                HOME="$tmphome" ${marp-cli}/bin/marp \
                  -I ${src} -o $out \
                  --allow-local-files \
                  --${outFormat}
                rm -rf "$tmphome"
              '');
            watch = { src ? "./src", assetPaths ? [ ] }:
              pkgs.mkShell {
                packages = [ marp-cli ];
                shellHook = code "bash" ''
                  tmpdir="$(${pkgs.coreutils}/bin/mktemp -d)"
                  ${lib.concatMapStrings (path: code "bash" ''
                    ln -s "$(realpath ${src}/${path})" "$tmpdir/"
                  '') assetPaths}
                  ${marp-cli}/bin/marp -I "./src" -o "$tmpdir" --watch --preview
                  rm -rf "$tmpdir"
                  exit
                '';
              };
            lint = { src }:
              pkgs.runCommand "lint-slides" { } (code "bash" ''
                ${pkgs.nodePackages.markdownlint-cli}/bin/markdownlint "${src}/*.md"
                touch "$out"
              '');
            spell = { src, config }:
              pkgs.runCommand "spellcheck-slides"
                {
                  CSPELL = "${pkgs.nodePackages.cspell}/bin/cspell";
                  SRC = "${src}";
                }
                (code "bash" ''
                  ${pkgs.nodePackages.cspell}/bin/cspell lint -r ${src} -c ${config} '*.md'
                  touch "$out"
                '');
          in
          {
            inherit watch lint spell;
            buildPdf = { src, assetPaths ? [ ] }:
              build { inherit src assetPaths; outFormat = "pdf"; };
            buildHtml = { src, assetPaths ? [ ] }:
              build { inherit src assetPaths; outFormat = "html"; };
          };
      };
    };
}
