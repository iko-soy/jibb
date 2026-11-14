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
          # static host fixture. Compilation is cached separately; compare
          # the assembled libraries with the exact sources that passed it.
          desks = pkgs.stdenvNoCC.mkDerivation {
            # No version in the name, so a commit that changes no desk
            # file reuses the last build.
            name = "jibb-desks";
            src = source deskFiles;
            nativeBuildInputs = [ python3 ];
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
                cmp desks/jibb-dev/lib/$lib.hoon ${librarySmoke}/$lib.hoon
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

          cliUnwrapped = pkgs.rustPlatform.buildRustPackage {
            pname = "jibb-cli";
            version = "0.1.0";
            src = cliSource;
            cargoLock.lockFile = ./jibb-cli/Cargo.lock;
            meta.mainProgram = "jibb";
          };
          jibb = pkgs.runCommand "jibb-cli-0.1.0" {
            nativeBuildInputs = [ pkgs.makeWrapper python3 ];
            meta = {
              description = "The Jibb command-line interface";
              mainProgram = "jibb";
            };
          } ''
              mkdir -p $out/bin
              # current_exe locates ../share/jibb; keep the executable here.
              cp ${cliUnwrapped}/bin/jibb $out/bin/jibb
              mkdir -p $out/share/jibb/tools
              install -m755 ${./tools/ship} $out/share/jibb/tools/ship
              install -m644 ${./tools/golden_case.py} $out/share/jibb/tools/golden_case.py
              install -m644 ${./tools/prelude_groups.py} $out/share/jibb/tools/prelude_groups.py
              cp -r ${./vendor} $out/share/jibb/vendor
              cp -r ${./jibb-dev} $out/share/jibb/jibb-dev
              cp -r ${./jibb} $out/share/jibb/jibb
              chmod -R u+w $out/share/jibb
              rm -rf $out/share/jibb/jibb-dev/tests
              patchShebangs $out/share/jibb/tools
              wrapProgram $out/share/jibb/tools/ship \
                --prefix PATH : ${lib.makeBinPath [ python3 urbit ]} \
                --set-default JIBB_CLICK ${lib.getExe click}
              mkdir unrelated
              cd unrelated
              # Fail in the installed helper before booting a pier, proving
              # current_exe finds that helper from outside the source tree.
              if $out/bin/jibb dev "$PWD/missing-app" > helper.log 2>&1; then
                echo "jibb dev unexpectedly accepted a missing application"
                exit 1
              fi
              grep -F "no application folder" helper.log
          '';

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

          # These standalone Hoon cores read no other desk sources. Keep
          # the original instrumented compilation checks mandatory for
          # desks without repeating them after unrelated fixture edits.
          librarySmoke = check "eval-library-smoke" (fs.unions [
            ./jibb-dev/lib/jibb.hoon ./jibb-dev/lib/jibb-import.hoon
            ./tools/hoon ./tools/urbit_eval.py ./tools/noun.py
          ]) (lib.concatStringsSep " " [
            "for lib in jibb jibb-import; do"
            ''echo "compiling $lib.hoon";''
            "tools/hoon --lib jibb-dev/lib/$lib.hoon '~' || exit $?;"
            "done"
          ]) {
            postBuild = ''
              cp jibb-dev/lib/jibb.hoon jibb-dev/lib/jibb-import.hoon $out/
            '';
          };

          evalManifest = builtins.fromJSON (builtins.readFile ./nix/eval-manifest.json);
          manifestFiles = paths: fs.unions (map (path: ./. + ("/" + path))
            (builtins.filter (path: builtins.pathExists (./. + ("/" + path))) paths));
          quote = values: builtins.concatStringsSep " " (map lib.escapeShellArg values);
          evalProbeParts = builtins.listToAttrs (map (batch: {
            name = "eval-${batch.name}";
            value = check "eval-${batch.name}" (manifestFiles batch.paths)
              "timeout 10800s python3 tools/probe-regression --fast ${quote batch.groups}" { };
          }) evalManifest.probe_batches);
          selftestFiles = fs.unions [
            (fs.difference deskFiles ./tests)
            ./tools/check ./tools/testdata/selftest
            ./tools/testdata/stub.hoon ./tools/testdata/golden ./tools/golden
            ./tools/test-arms ./tools/doc-blocks ./tools/bundle-js
            ./tools/probe-regression ./tools/check-my-app
            # The real-compiler crash fixture and its linked mark source.
            ./tests/golden/types-import-mark ./tests/clay-fixtures/desk/mar/label.hoon
            # probe-regression reads these when the selftest imports it.
            ./tests/type-probe/import-exact.txt ./tests/type-probe/diagnostics.txt
          ];
          evalSelftest = check "eval-selftest" selftestFiles
            "tools/check selftest --timeout 10800 --logs $out" {
              nativeBuildInputs = [ python3 urbit nodejs esbuild terser ];
            };
          residualNames = builtins.filter
            (name: name != "probes-eval" && name != "selftest") evalManifest.residual;
          residual = check "eval-residual" checkFiles
            "tools/check ${quote residualNames} -j 1 --timeout 10800 --logs $out" {
              nativeBuildInputs = [ python3 urbit nodejs esbuild terser cliUnwrapped ];
            };
          manifestCheck = check "eval-manifest" (fs.unions [checkFiles ./nix/eval-manifest.json])
            "tools/eval-manifest --check" { };
          goldenParts = builtins.listToAttrs (map (batch: {
            name = "eval-${batch.name}";
            value = check "eval-${batch.name}" (manifestFiles batch.paths)
              "timeout 10800s tools/golden --fast --jobs 1 ${quote (builtins.concatMap (case: [ "--case" case ]) batch.cases)}" { };
          }) evalManifest.golden_batches);
          armParts = builtins.listToAttrs (map (batch: {
            name = "eval-${batch.name}";
            value = let
              desk = pkgs.writeText "${batch.name}-desk.json" (builtins.toJSON batch.desk);
            in check "eval-${batch.name}" (manifestFiles batch.paths)
              "timeout 10800s tools/test-arms --fast --desk-map ${desk} --timeout 3600 ${quote batch.suites}" { };
          }) evalManifest.arm_batches);
          evalParts = goldenParts // armParts // evalProbeParts // {
            # Keep the certified sources alive through CI cache GC too:
            # desks only uses them while building, not in its output.
            inherit residual manifestCheck evalSelftest librarySmoke;
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
          mappedShipExtra = batch: directShipExtra // {
            JIBB_DESK_MAPS = pkgs.writeText "${batch.name}-ship-desks.json"
              (builtins.toJSON batch.ship_desks);
          };
          shipSuiteParts = builtins.listToAttrs (map (batch: {
            name = "ship-${batch.name}";
            value = check "ship-${batch.name}" (manifestFiles batch.ship_paths)
              "timeout 10800s python3 tools/ship test --only suites ${quote (builtins.concatMap (suite: [ "--suite" suite ]) batch.suites)}" (mappedShipExtra batch);
          }) evalManifest.arm_batches);
          # The selftest checks full desk assembly as well as stub runs.
          shipSelftest = check "ship-selftest" (fs.unions [
            shipTestFiles ./tests ./tools/testdata
          ]) "tools/check ship-selftest --timeout 10800 --logs $out" shipExtra;
          shipGoldens = check "ship-goldens" (fs.unions (
            [ shipTestFiles ] ++ map (batch: manifestFiles batch.paths) evalManifest.golden_batches
          )) "tools/check ship-test-goldens --timeout 10800 --logs $out" shipExtra;
          shipBaseFiles = fs.unions [
            shipTestFiles ./tools/clay-fixtures ./tools/check-my-app
            ./tests/clay-fixtures ./tests/type-buttons/error.txt
            # The Clay fixture's real Tlon /sur is a symlink here.
            ./tests/golden/types-import-tlon-notes/sur
            ./tests/type-import-general/sur.txt
          ];
          shipBase = check "ship-base" shipBaseFiles
            "tools/check check-commit clay-fixtures check-my-app --timeout 10800 --logs $out" shipExtra;
          shipProbeParts = builtins.listToAttrs (map (batch: {
            name = "ship-${batch.name}";
            value = check "ship-${batch.name}" (manifestFiles batch.ship_paths)
              "timeout 10800s python3 tools/probe-regression --backend ship ${quote batch.groups}"
              (mappedShipExtra batch);
          }) evalManifest.probe_batches);
          shipHostFiles = fs.unions [
            shipTestFiles ./tests/host-fixture ./js
            ./tools/check-host ./tools/check-browser ./tools/browser-check.mjs
            ./tools/check-node-tests ./tools/node-tests.mjs
          ];
          shipHost = check "ship-host" shipHostFiles
            "JIBB_CHECK_TIMINGS=$out/timings.jsonl timeout 10800s python3 tools/check-host --clients --leave-suspended"
            (shipExtra // {
              # Keep stdenv's EXIT handler so failures retain the ship log.
              preBuild = shipExtra.preBuild + ''
                python3 tools/ship start
              '';
              exitHook = "python3 tools/ship stop --force";
              failureHook = shipExtra.failureHook + ''
                python3 tools/ship stop --force
              '';
              nativeBuildInputs = [ python3 urbit nodejs esbuild terser pkgs.chromium ];
              FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
              postBuild = ''
                python3 - <<'PY'
                import json, os
                from pathlib import Path
                for line in (Path(os.environ['out']) / 'timings.jsonl').read_text().splitlines():
                    phase = json.loads(line)
                    if phase['event'] == 'finish' and phase['depth'] <= 1:
                        print("{tool}: {name}: {elapsed:.3f} s ({status})".format(**phase))
                PY
              '';
            });
          shipParts = shipSuiteParts // shipProbeParts // {
            inherit shipSelftest shipGoldens shipBase shipHost;
          };
          shipChecks = pkgs.linkFarm "jibb-check-ship" (lib.mapAttrsToList
            (name: path: { inherit name path; }) shipParts);
        in
        {
          packages = {
            inherit desks click jibb;
            jibb-cli-unwrapped = cliUnwrapped;
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
