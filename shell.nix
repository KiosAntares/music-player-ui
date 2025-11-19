let 
  pkgs = import <nixpkgs> {};
in pkgs.mkShell {
    packages = [
        pkgs.playerctl
        pkgs.ruff
    (pkgs.python3.withPackages (python-pkgs: with python-pkgs;[
      pygame-ce
      requests
      python-dotenv
    ]))
  ];
}
