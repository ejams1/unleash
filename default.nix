{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation rec {
  pname = "unleash";
  version = "2.0.0";

  src = ./.;

  installPhase = ''
    mkdir -p $out/bin
    cp unleash $out/bin/
    chmod +x $out/bin/unleash
    # The script loads its modules from <script dir>/lib, so the modules ship
    # next to the binary; $out/lib is never consulted.
    cp -r lib $out/bin/lib/
    cp -r examples $out/share/unleash/
  '';

  meta = with pkgs.lib; {
    description = "Single-script MDM bypass for macOS";
    homepage = "https://github.com/mateussiqueira/unleash";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [ maintainers.mateussiqueira ];
  };
}
