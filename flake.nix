{
  description = "Jibb, a UI language for Urbit: its desks, and the repo's checks";

  inputs = {
    # A channel tarball rather than github:NixOS/nixpkgs, so the flake
    # also fetches where GitHub's archive downloads are blocked, as in a
    # restricted cloud container.  flake.lock pins the exact release.
    # nixos-unstable has vere 4.6, which the tools were written against.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    # click, which tools/ship formats its requests to the ship with.
    urbit-tools = {
      url = "git+https://github.com/urbit/tools";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, urbit-tools }:
    let
      # The platforms nixpkgs builds vere for.
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forSystems = f: nixpkgs.lib.genAttrs systems
        (system: f nixpkgs.legacyPackages.${system});
      inherit (nixpkgs) lib;
      fs = lib.fileset;

      # What the desks are assembled from, and the tools that assemble
      # them and compile their libraries.
      deskFiles = fs.unions [
        ./jibb
        ./jibb-dev
        ./my-app
        ./vendor
        ./tests
        ./tools/ship
        ./tools/golden_case.py
        ./tools/prelude_groups.py
        ./tools/hoon
        ./tools/urbit_eval.py
        ./tools/noun.py
      ];
      cliFiles = fs.unions [
        ./jibb-cli/Cargo.toml
        ./jibb-cli/Cargo.lock
        ./jibb-cli/build.rs
        ./jibb-cli/grammar.js
        ./jibb-cli/src
        ./jibb-cli/tests
      ];
      # What the checks read: the desks, CLI, tools, spec tabs and review
      # regression corpus. Other documentation does not rerun checks.
      checkFiles = fs.unions [
        deskFiles cliFiles ./tools ./docs/spec ./js
        ./docs/reviews/2026-11-03-milestone-2-probes
      ];
      source = fileset: fs.toSource { root = ./.; inherit fileset; };
      cliSource = fs.toSource { root = ./jibb-cli; fileset = cliFiles; };

      perSystem = pkgs:
        let
          inherit (pkgs) python3 urbit cargo rustc rustfmt clippy tree-sitter nodejs;
          isLinux = pkgs.stdenv.hostPlatform.isLinux;

          click = pkgs.stdenvNoCC.mkDerivation {
            pname = "click";
            version = "0-unstable-${builtins.substring 0 8 urbit-tools.lastModifiedDate}";
            src = urbit-tools;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [ pkgs.bash ];
            installPhase = ''
              runHook preInstall
              # click runs click-format from its own folder.
              install -Dm755 -t $out/libexec/click \
                pkg/click/click pkg/click/click-format
              makeWrapper $out/libexec/click/click $out/bin/click \
                --prefix PATH : ${lib.makeBinPath [ pkgs.coreutils pkgs.gnused ]} \
                --prefix PATH : ${pkgs.netcat}/bin
              runHook postInstall
            '';
            meta = {
              description = "Thin client for a running Urbit ship's conn.sock";
              homepage = "https://github.com/urbit/tools";
              license = lib.licenses.mit;
              mainProgram = "click";
            };
          };

          # The brass pill from the urbit/urbit commit vendor/ is copied
          # from (vendor/SOURCES.txt).  GitHub serves it from Git LFS.
          pill = pkgs.fetchurl {
            name = "brass.pill";
            url = "https://media.githubusercontent.com/media/urbit/urbit/50c7f5239610fc72263df7aa99b4d171cfe9d408/bin/brass.pill";
            hash = "sha256-tLq9FOnxrL20IbPDHCFe5jetZpG344K5nG/YmR5iNwg=";
          };

          # A freshly booted fake ~zod: the pier itself.  Booting takes
          # about half a minute; the ship checks start a copy of it.
          fakezod = pkgs.runCommand "fakezod" {
            nativeBuildInputs = [ urbit ];
          } ''
            urbit -F zod -B ${pill} -t -x -c zod
            test -d zod/.urb/log
            mv zod $out
          '';

          # The desks, as tools/ship assembles them for the ship:
          # $out/my-app, $out/jibb, $out/jibb-dev, the test desk,
          # $out/jibb-fixtures for the Clay fixtures, and the real-Clay
          # static host fixture.  The check phase compiles the two libraries
          # under urbit eval.
          desks = pkgs.stdenvNoCC.mkDerivation {
            # No version in the name, so a commit that changes no desk
            # file reuses the last build.
            name = "jibb-desks";
            src = source deskFiles;
            nativeBuildInputs = [ python3 ];
            nativeCheckInputs = [ urbit ];
            dontConfigure = true;
            buildPhase = ''
              runHook preBuild
              patchShebangs tools > /dev/null
              tools/ship assemble --out desks
              runHook postBuild
            '';
            doCheck = true;
            checkPhase = ''
              runHook preCheck
              for lib in jibb jibb-import; do
                echo "compiling $lib.hoon"
                tools/hoon --lib desks/jibb-dev/lib/$lib.hoon '~'
              done
              runHook postCheck
            '';
            installPhase = ''
              runHook preInstall
              mv desks $out
              runHook postInstall
            '';
            # The files are the desks' as they are: nothing to patch.
            dontFixup = true;
            meta = {
              description = "The Jibb desks, test fixtures, and static host fixture";
              platforms = systems;
            };
          };

          jibb = pkgs.rustPlatform.buildRustPackage {
            pname = "jibb-cli";
            version = "0.1.0";
            src = cliSource;
            cargoLock.lockFile = ./jibb-cli/Cargo.lock;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postInstall = ''
              mkdir -p $out/share/jibb/tools
              install -m755 ${./tools/ship} $out/share/jibb/tools/ship
              install -m644 ${./tools/golden_case.py} $out/share/jibb/tools/golden_case.py
              install -m644 ${./tools/prelude_groups.py} $out/share/jibb/tools/prelude_groups.py
              cp -r ${./vendor} $out/share/jibb/vendor
              cp -r ${./jibb-dev} $out/share/jibb/jibb-dev
              cp -r ${./jibb} $out/share/jibb/jibb
              chmod -R u+w $out/share/jibb
              rm -rf $out/share/jibb/jibb-dev/tests
              wrapProgram $out/share/jibb/tools/ship \
                --prefix PATH : ${lib.makeBinPath [ python3 urbit ]} \
                --set-default JIBB_CLICK ${lib.getExe click}
            '';
            meta = {
              description = "The Jibb command-line interface";
              mainProgram = "jibb";
            };
          };

          # A check: tools/check run on the repo with the given arguments.
          check = name: args: extra: pkgs.stdenvNoCC.mkDerivation ({
            name = "jibb-check-${name}";
            src = source checkFiles;
            nativeBuildInputs = [ python3 urbit nodejs ];
            dontConfigure = true;
            dontInstall = true;
            dontFixup = true;
            buildPhase = ''
              runHook preBuild
              patchShebangs tools docs/reviews/2026-11-03-milestone-2-probes/run > /dev/null
              mkdir $out
              tools/check ${args} --timeout 10800 --logs $out
              runHook postBuild
            '';
          } // extra);

          # Every check that needs only urbit and Python, with bounded eval concurrency.
          evalChecks = check "eval" "--group eval -j 2" { };

          # The checks that need a ship, on a writable copy of fakezod.
          shipChecks = check "ship" "--group ship" {
            preBuild = ''
              cp -r ${fakezod} $TMPDIR/zod
              chmod -R u+w $TMPDIR/zod
              export JIBB_PIER=$TMPDIR/zod
              export JIBB_CLICK=${lib.getExe click}
            '';
            # A failed run shows the end of the ship's log too.
            failureHook = ''
              echo "the end of the ship's log, $TMPDIR/zod.log:"
              tail -n 100 $TMPDIR/zod.log || true
            '';
          };
        in
        {
          packages = {
            inherit desks click jibb;
            default = desks;
          } // lib.optionalAttrs isLinux { inherit fakezod; };

          checks = {
            inherit desks;
            jibb-cli = jibb;
            eval = evalChecks;
          } // lib.optionalAttrs isLinux { ship = shipChecks; };

          devShells.default = pkgs.mkShell {
            packages = [ python3 urbit click cargo rustc rustfmt clippy tree-sitter nodejs ];
            # tools/ship looks for click here; the pier stays
            # /root/urbit/zod unless $JIBB_PIER says otherwise.
            JIBB_CLICK = lib.getExe click;
          };
        };

      all = forSystems perSystem;
    in
    {
      packages = lib.mapAttrs (_: s: s.packages) all;
      checks = lib.mapAttrs (_: s: s.checks) all;
      devShells = lib.mapAttrs (_: s: s.devShells) all;
    };
}
