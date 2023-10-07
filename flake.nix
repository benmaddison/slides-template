{
  description = "Template repository for slides using nix and marp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nix-marp = {
      url = "github:tweag/nix-marp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, ... } @ inputs:
    let code = _: s: s; in
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
            build = { src, outFormat }:
              pkgs.runCommand "build-${outFormat}-slides" { } (code "bash" ''
                mkdir -p $out
                ${marp-cli}/bin/marp -I ${src} -o $out --${outFormat}
              '');
            watch = { src ? "./src" }:
              pkgs.mkShell {
                packages = [ marp-cli ];
                shellHook = code "bash" ''
                  tmpdir="$(${pkgs.coreutils}/bin/mktemp -d)"
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
            buildPdf = { src }: build { inherit src; outFormat = "pdf"; };
            buildHtml = { src }: build { inherit src; outFormat = "html"; };
          };
      };
    };
}