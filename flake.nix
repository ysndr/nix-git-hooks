{
  description = "A basic flake with a shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    {
      lib.mkInstaller = pkgs: hookTypes:
        let
          mkHook = type: hooks: {
            hook = pkgs.writeShellScript type ''
              for hook in ${
                pkgs.symlinkJoin {
                  name = "${type}-git-hooks";
                  paths = hooks;
                }
              }/bin/*; do
              $hook "$@"
              RESULT=$?
              if [ $RESULT != 0 ]; then
                  echo "$hook returned non-zero: $RESULT, abort operation"
              exit $RESULT
              fi
              done
              echo "$INSTALLED_GIT_HOOKS $type"
              exit 0
            '';
            inherit type;
          };

          installHookScript = { type, hook }: ''
            if [[ -e .git/hooks/${type} ]]; then
                echo "Warn: ${type} hook already present, skipping"
            else
                ln -s ${hook} $PWD/.git/hooks/${type}
                INSTALLED_GIT_HOOKS+=(${type})
            fi
          '';

          uninstaller = self.lib.mkUninstaller pkgs;
        in
        pkgs.writeShellScriptBin "install-git-hooks" ''
          if [[ ! -d .git ]] || [[ ! -f flake.nix ]]; then
              echo "Invocate \`nix develop\` from the project root directory."
              exit 1
          fi

          if [[ -e .git/hooks/nix-installed-hooks ]]; then
              echo "Hooks already installed, reinstalling"
              ${uninstaller}/bin/${uninstaller.name}
          fi

          mkdir -p ./.git/hooks

          ${pkgs.lib.concatStringsSep "\n" (nixpkgs.lib.mapAttrsToList
            (type: hooks: installHookScript (mkHook type hooks)) hookTypes)}

          echo "Installed git hooks: $INSTALLED_GIT_HOOKS"
          printf "%s\n" "''${INSTALLED_GIT_HOOKS[@]}" > .git/hooks/nix-installed-hooks
        '';

      lib.mkUninstaller = pkgs:
        pkgs.writeShellScriptBin "uninstall-git-hooks" ''
          if [[ ! -e "$PWD/.git/hooks/nix-installed-hooks" ]]; then
          echo "Error: could find list of installed hooks."
          exit 1
          fi

          while read -r hook
          do
          echo "Uninstalling $hook"
          rm "$PWD/.git/hooks/$hook"
          done < "$PWD/.git/hooks/nix-installed-hooks"

          rm "$PWD/.git/hooks/nix-installed-hooks"
        '';

      overlay = final: prev: {
        git-hook-installer = self.lib.mkInstaller prev;
        git-hook-uninstaller = self.lib.mkUninstaller prev;
      };

    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        };

      in
      {
        devShell =
          let
            nixFormatHook = pkgs.writeShellScriptBin "check-rust-format-hook" ''
              ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check flake.nix
              RESULT=$?
              [ $RESULT != 0 ] && echo "Please run \`nixpkgs-fmt\` before committing"
              exit $RESULT
            '';

            hookInstaller =
              pkgs.git-hook-installer { pre-commit = [ nixFormatHook ]; };
          in
          pkgs.mkShell {
            packages = [ hookInstaller pkgs.git-hook-uninstaller ];
            inputsFrom = [ ];

            shellHook = ''
              echo "=== Development shell ==="
              echo "Info: Git hooks can be installed using \`install-git-hooks\`"
              # or run `install-git-hooks` automatically
            '';
          };
      });
}
