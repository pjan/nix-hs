################################################################################
#
# This file is part of the package nix-hs. It is subject to the license
# terms in the LICENSE file found in the top-level directory of this
# distribution and at:
#
#   git://git.devalot.com/nix-hs.git
#
# No part of this package, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in
# the LICENSE file.
#
################################################################################
{ pkgs         ? (import <nixpkgs> {}).pkgs
, compiler     ? "default" # Which version of GHC to use, or "default".
, profiling    ? false     # Enable profiling or not.
, optimization ? true      # Enable optimization or not.
, file                     # The package file (default.nix) to load.
}:

with pkgs.lib;

let

  # Some handy bindings:
  cabal = "${basePackages.cabal-install}/bin/cabal";

  cabalConfigureFlags = concatStringsSep " "
    [ (optionalString optimization "--enable-optimization")
      (optionalString profiling    "--enable-profiling")
      "--enable-tests" # Safe to always keep on.
    ];

  # These are the shell functions that `nix-hs' will call into.
  shellFunctions = "\n" + ''
    # NOTE: This is here because the generic Haskell builder doesn't
    # end it's shellHook with a newline and so we get syntax errors
    # without the blank line above.
    alias cabal='${cabal} --config-file=/dev/null'

    do_cabal_configure() {
      set -e
      cabal configure ${cabalConfigureFlags}
    }

    do_cabal_build() {
      set -e
      cabal build
    }

    do_cabal_test() {
      set -e
      cabal test
    }

    do_cabal_clean() {
      set -e
      cabal clean
    }

    do_cabal_repl() {
      set -e
      cabal repl "$@"
    }

    do_cabal_haddock() {
      set -e
      cabal haddock
    }
  '';

  # Select a compiler:
  basePackages =
    if compiler == "default"
      then pkgs.haskellPackages
      else pkgs.haskell.packages."ghc${compiler}";

  # Override the Haskell package set with the one from above:
  alteredPackages = pkgs // { haskellPackages = basePackages; };

  # Load the local file and override its shell environment:
  drv = (import file { pkgs = alteredPackages; }).overrideAttrs (orig: {
    passthru = orig.passthru // {
      env = orig.passthru.env.overrideAttrs (_env: {
        shellHook = _env.shellHook + shellFunctions;
      });
    };
  });

in drv.env
