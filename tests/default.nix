{ pkgs, treefmt-nix, ... }:
let
  inherit (pkgs) lib;

  join = lib.concatStringsSep;

  toConfig = name:
    treefmt-nix.mkConfigFile pkgs {
      programs.${name}.enable = true;
    };

  programConfigs = lib.listToAttrs (map
    (name: { name = name; value = toConfig name; })
    treefmt-nix.programs.names
  );

  borsToml =
    let
      checks = map (name: ''  "check ${name} [x86_64-linux]"'') (lib.attrNames self);
    in
    pkgs.writeText "bors.toml" ''
      # Generated with ./bors.toml.sh
      cut_body_after = "" # don't include text from the PR body in the merge commit message
      status = [
        "Evaluate flake.nix",
        ${join ",\n  " checks},
      ]
    '';

  examples =
    let
      configs = lib.mapAttrs
        (name: value:
          ''
            {
              echo "# Example generated by ../examples.sh"
              sed -n '/^$/q;p' ${value} | sed 's|\(command = "\).*/\([^"]\+"\)|\1\2|'
            } > "$out/${name}.toml"
          ''
        )
        programConfigs;
    in
    pkgs.runCommand "examples" { } ''
      mkdir $out

      ${join "\n" (lib.attrValues configs)}
    '';

  self = {
    testEmptyConfig = treefmt-nix.mkConfigFile pkgs { };

    testWrapper = treefmt-nix.mkWrapper pkgs {
      projectRootFile = "flake.nix";
    };

    # Check if the bors.toml needs to be updated
    testBorsToml = pkgs.runCommand
      "test-bors-toml"
      {
        passthru.borsToml = borsToml;
      }
      ''
        if ! diff ${../bors.toml} ${borsToml}; then
          echo "The generated ./bors.toml is out of sync"
          echo "Run ./bors.toml.sh to fix the issue"
          exit 1
        fi
        touch $out
      '';

    # Check if the examples folder needs to be updated
    testExamples = pkgs.runCommand
      "test-examples"
      {
        passthru.examples = examples;
      }
      ''
        if ! diff -r ${../examples} ${examples}; then
          echo "The generated ./examples folder is out of sync"
          echo "Run ./examples.sh to fix the issue"
          exit 1
        fi
        touch $out
      '';
  } // programConfigs;
in
self
