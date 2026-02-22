{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  common-updater-scripts,
  curl,
  exiv2,
  jq,
  mpv,
  nix-update,
  opencv4,
  pkg-config,
  qt6,
  writeShellScript,
}:

stdenv.mkDerivation {
  pname = "qimgv";
  version = "1.0.3-unstable-2026-01-19";

  src = fetchFromGitHub {
    owner = "easymodo";
    repo = "qimgv";
    rev = "3127a2d211b124ad4fcf853d01e6df9323bdfdc3";
    sha256 = "sha256-avn02kdMyA5PZUSykxgIk1I78zHQ/WKd26tQO8lMOow=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];

  cmakeFlags = [
    "-DVIDEO_SUPPORT=ON"
    "-DUSE_QT5=OFF"
  ];

  buildInputs = [
    exiv2
    mpv
    opencv4
    qt6.qtbase
    qt6.qtsvg
    qt6.qttools
  ];

  postPatch = ''
    substituteInPlace qimgv/settings.cpp \
      --replace-fail '"/usr/bin/mpv"' '"'${lib.escapeShellArg (lib.getExe mpv)}'"'
  '';

  # qimgv's git latest tag has `-alpha` suffix which we don't want to put in version
  passthru.updateScript = writeShellScript "update-qimgv" ''
    ${lib.getExe nix-update} qimgv --version branch=HEAD

    latestTag=$(
      ${lib.getExe curl} -s "https://api.github.com/repos/easymodo/qimgv/tags?per_page=1" \
        | ${lib.getExe jq} -r '.[0].name | ltrimstr("v") | split("-") | .[0]'
    )
    latestDate=$(
      ${lib.getExe curl} -s "https://api.github.com/repos/easymodo/qimgv/commits/HEAD" \
        | ${lib.getExe jq} -r '.commit.committer.date | .[0:10]'
    )

    ${lib.getExe' common-updater-scripts "update-source-version"} qimgv \
      "''${latestTag}-unstable-''${latestDate}" --ignore-same-hash
  '';

  meta = {
    description = "Qt6 image viewer with optional video support";
    mainProgram = "qimgv";
    homepage = "https://github.com/easymodo/qimgv";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [
      amozeo
      cole-h
    ];
  };
}
