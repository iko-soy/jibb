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
          inherit (pkgs) python3 urbit cargo rustc rustfmt clippy tree-sitter nodejs esbuild terser;
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

          check = name: fileset: command: extra: pkgs.stdenvNoCC.mkDerivation ({
            inherit name;
            src = source fileset;
            nativeBuildInputs = [ python3 urbit ];
            dontConfigure = true;
            dontInstall = true;
            dontFixup = true;
            buildPhase = ''
              runHook preBuild
              patchShebangs tools > /dev/null
              if test -d docs/reviews/2026-11-03-milestone-2-probes; then
                patchShebangs docs/reviews/2026-11-03-milestone-2-probes/run > /dev/null
              fi
              mkdir $out
              set -o pipefail
              ${command} 2>&1 | tee $out/check.log
              runHook postBuild
            '';
          } // extra);

          evalManifest = builtins.fromJSON (builtins.readFile ./nix/eval-manifest.json);
          manifestFiles = paths: fs.unions (map (path: ./. + ("/" + path))
            (builtins.filter (path: builtins.pathExists (./. + ("/" + path))) paths));
          quote = values: builtins.concatStringsSep " " (map lib.escapeShellArg values);
          probeEvalFiles = fs.unions [
            ./jibb-dev ./my-app ./vendor ./jibb
            ./tools/check ./tools/probe-regression ./tools/check-my-app ./tools/ship
            ./tools/hoon ./tools/urbit_eval.py ./tools/noun.py
            ./tools/golden_case.py ./tools/prelude_groups.py
            ./docs/reviews/2026-11-03-milestone-2-probes
            ./tests/type-probe ./tests/type-buttons/error.txt
            ./tests/golden/doc-core-02-update ./tests/clay-fixtures/my-app.txt
          ];
          evalProbes = check "eval-probes" probeEvalFiles
            "tools/check probes-eval --timeout 10800 --logs $out" { };
          selftestFiles = fs.unions [deskFiles ./tools ./docs/spec ./js];
          evalSelftest = check "eval-selftest" selftestFiles
            "tools/check selftest --timeout 10800 --logs $out" {
              nativeBuildInputs = [ python3 urbit nodejs esbuild terser ];
            };
          residualNames = builtins.filter
            (name: name != "probes-eval" && name != "selftest") evalManifest.residual;
          residual = check "eval-residual" checkFiles
            "tools/check ${quote residualNames} -j 1 --timeout 10800 --logs $out" {
              nativeBuildInputs = [ python3 urbit nodejs esbuild terser jibb ];
            };
          manifestCheck = check "eval-manifest" (fs.unions [checkFiles ./nix/eval-manifest.json])
            "tools/eval-manifest --check" { };
          goldenParts = builtins.listToAttrs (map (batch: {
            name = "eval-${batch.name}";
            value = check "eval-${batch.name}" (manifestFiles batch.paths)
              "timeout 10800s tools/golden --jobs 1 ${quote (builtins.concatMap (case: [ "--case" case ]) batch.cases)}" { };
          }) evalManifest.golden_batches);
          armParts = builtins.listToAttrs (map (batch: {
            name = "eval-${batch.name}";
            value = let
              desk = pkgs.writeText "${batch.name}-desk.json" (builtins.toJSON batch.desk);
            in check "eval-${batch.name}" (manifestFiles batch.paths)
              "timeout 10800s tools/test-arms --desk-map ${desk} --timeout 3600 ${quote batch.suites}" { };
          }) evalManifest.arm_batches);
          evalParts = goldenParts // armParts // {
            inherit residual manifestCheck evalProbes evalSelftest;
          };
          evalChecks = pkgs.linkFarm "jibb-check-eval" (lib.mapAttrsToList
            (name: path: { inherit name path; }) evalParts);

          shipTestFiles = fs.unions [
            ./jibb-dev ./my-app ./vendor ./jibb
            ./tools/check ./tools/ship ./tools/golden_case.py ./tools/prelude_groups.py
          ];
          shipExtra = {
            preBuild = ''
              cp -r ${fakezod} $TMPDIR/zod
              chmod -R u+w $TMPDIR/zod
              export JIBB_PIER=$TMPDIR/zod
              export JIBB_CLICK=${lib.getExe click}
            '';
            failureHook = ''
              echo "the end of the ship's log, $TMPDIR/zod.log:"
              tail -n 100 $TMPDIR/zod.log || true
            '';
          };
          directShipExtra = shipExtra // {
            preBuild = shipExtra.preBuild + ''
              python3 tools/ship start
              trap 'python3 tools/ship stop --force' EXIT
            '';
          };
          shipSuiteParts = builtins.listToAttrs (map (batch: {
            name = "ship-${batch.name}";
            value = check "ship-${batch.name}" (fs.unions [
              shipTestFiles (manifestFiles batch.paths)
            ]) "timeout 10800s python3 tools/ship test --only suites ${quote (builtins.concatMap (suite: [ "--suite" suite ]) batch.suites)}" directShipExtra;
          }) evalManifest.arm_batches);
          shipGoldens = check "ship-goldens" (fs.unions [
            shipTestFiles ./tests ./tools/testdata
          ]) "tools/check ship-selftest ship-test-goldens --timeout 10800 --logs $out" shipExtra;
          shipIntegrationFiles = fs.unions [
            deskFiles ./tools ./docs/spec ./js ./tests
            ./docs/reviews/2026-11-03-milestone-2-probes
          ];
          shipBase = check "ship-base" shipIntegrationFiles
            "tools/check check-commit clay-fixtures check-my-app --timeout 10800 --logs $out" shipExtra;
          shipProbes = check "ship-probes" shipIntegrationFiles
            "tools/check probes-ship --timeout 10800 --logs $out" shipExtra;
          shipHost = check "ship-host" shipIntegrationFiles
            "tools/check check-host check-browser check-node-tests --timeout 10800 --logs $out"
            (shipExtra // {
              nativeBuildInputs = [ python3 urbit nodejs esbuild terser pkgs.chromium ];
              FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
            });
          shipParts = shipSuiteParts // {
            inherit shipGoldens shipBase shipProbes shipHost;
          };
          shipChecks = pkgs.linkFarm "jibb-check-ship" (lib.mapAttrsToList
            (name: path: { inherit name path; }) shipParts);
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
            packages = [ python3 urbit click cargo rustc rustfmt clippy tree-sitter nodejs esbuild terser ]
              ++ lib.optionals isLinux [ pkgs.chromium ];
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
