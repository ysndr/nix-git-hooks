# Nix Git Hooks

This repository is the accompanying library to my [blog post](https://blog.ysndr.de/posts/code/2021-12-02-git-hooks/).

The flake provides two library functions `mkInstaller` and `mkUninstaller` that can be used to create commands to install and unsinstall git hooks respectively.

# Usage

Include the flake as input to your own flake:

```nix
inputs.nix-git-hooks.url = "github:ysndr/nix-git-hook";
```

Define git hooks, for example:

```nix
nixFormatHook = pkgs.writeShellScriptBin "check-rust-format-hook" ''
    ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check flake.nix
    RESULT=$?
    [ $RESULT != 0 ] && echo "Please run \`nixpkgs-fmt\` before committing"
    exit $RESULT
'';
```

Generate an installer and uninstaller:

```nix
# Using the overlay
hookInstaller =
    pkgs.git-hook-installer { pre-commit = [ nixFormatHook ]; };
hookUninstaller = pkgs.git-hook-uninstaller;

# Using the library
hookInstaller =
    nix-git-hooks.lib.mkInstaller pkgs { 
        pre-commit = [ nixFormatHook ];
        # see https://git-scm.com/docs/githooks for more hook types
    };

hookUninstaller = nix-git-hooks.lib.mkUninstaller pkgs;
```

Include the (un)installer in your shell

```nix
pkgs.mkShell {
    packages = [ hookInstaller hookUninstaller ];
    shellHook = ''
        echo "=== Development shell ==="
        echo "Info: Git hooks can be installed using \`install-git-hooks\`"
        # or run `install-git-hooks` automatically
    '';
};
```
