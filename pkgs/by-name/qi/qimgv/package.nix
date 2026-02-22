{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  exiv2,
  mpv,
  opencv4,
  pkg-config,
  qt6,
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

  meta = {
    description = "Qt6 image viewer with optional video support";
    mainProgram = "qimgv";
    homepage = "https://github.com/easymodo/qimgv";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ cole-h ];
  };
}
