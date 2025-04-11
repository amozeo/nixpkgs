{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage {
  pname = "btc-rpc-explorer";
  version = "3.4.0-unstable-2024-12-16";

  src = fetchFromGitHub {
    owner = "janoside";
    repo = "btc-rpc-explorer";
    rev = "f0b81a1ccf9c8722fa78eb6e3092761a6cd38edb";
    hash = "sha256-UzTNw5YRJKwIF3Yf3uLm9tGJkHQK3XJGYCLoy9CI9xo=";
  };

  npmDepsHash = "sha256-kHHiyB+VAbgbLJs9S4B0qv+3IC07LM4auSIFbJQ34fM=";

  postPatch = ''
    ln -s npm-shrinkwrap.json package-lock.json
  '';

  makeCacheWritable = true;

  dontNpmBuild = true;

  meta = {
    description = "Database-free, self-hosted Bitcoin explorer, via RPC to Bitcoin Core";
    homepage = "https://github.com/janoside/btc-rpc-explorer";
    license = lib.licenses.mit;
    mainProgram = "btc-rpc-explorer";
    maintainers = with lib.maintainers; [ d-xo ];
  };
}
