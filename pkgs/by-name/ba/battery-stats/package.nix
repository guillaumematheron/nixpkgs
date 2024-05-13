{
  stdenv,
  cmake,
  copyDesktopItems,
  fetchFromGitHub,
  lib,
  makeDesktopItem,
  gnuplot,
  makeWrapper,
  fetchurl,
  bc,
}:
let gnuplotOld = gnuplot.overrideAttrs (oldAttrs: rec {
  pname = "gnuplot";
  version = "5.4.10";
  src = fetchurl {
    url = "mirror://sourceforge/gnuplot/${pname}-${version}.tar.gz";
    sha256 = "sha256-l12MHMLEHHztxOMjr/A12Xf+ual/ApbdKopm0Zelsnw=";
  };
  # src = oldAttrs.src.override {
  #   sha256 = "15hflax5qkw1v6nssk1r0wkj83jgghskcmn875m3wgvpzdvajncd";
  # };
});
in
stdenv.mkDerivation rec {
  name = "battery-stats";
  version = "0.5.6";

  src = fetchFromGitHub {
    owner = "petterreinholdtsen";
    repo = "battery-stats";
    rev = "7a1963c88eee376d94793c239d9d69b885f38b96";
    sha256 = "sha256-YYAwdBgDk8tCNYoAhhLoGqSc6Jww+FWdrn6hjgygVRw=";
  };

  nativeBuildInputs = [ cmake makeWrapper ];

  prePatch = ''
    substituteInPlace data/CMakeLists.txt --replace-fail "/etc" "\''${CMAKE_INSTALL_PREFIX}/etc"
    cat data/CMakeLists.txt
  '';

  configurePhase = ''
    cmake .
  '';

  buildPhase = ''
    make
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/debug
    mkdir -p $out/src

    cp -rf * $out/debug
    cp -rf $src $out/src

    cp src/battery-graph $out/bin/battery-graph.wrapped
    cp $src/src/battery-log $out/bin
    chmod +x $out/bin/battery-graph.wrapped
    chmod +x $out/bin/battery-log

    substituteInPlace $out/bin/battery-graph.wrapped --replace-fail "/var/empty/local" "$out/var/empty/local"

    make install PREFIX=$out DESTDIR=$out \
        SYSTEMD_UNIT_DIR=/lib/systemd/system \
        UDEV_RULES_DIR=/etc/udev/rules.d

    makeWrapper $out/bin/battery-graph.wrapped $out/bin/battery-graph \
      --prefix PATH : $out/bin:${lib.makeBinPath [ gnuplotOld ]}

    mv $out/var/empty/local/sbin/battery-stats-collector $out/var/empty/local/sbin/battery-stats-collector.wrapped
    makeWrapper $out/var/empty/local/sbin/battery-stats-collector.wrapped $out/var/empty/local/sbin/battery-stats-collector \
      --prefix PATH : ${lib.makeBinPath [ bc ]}


    # install -Dm644 battery-stats.jar $out/share/java/battery-stats.jar
    # install -Dm644 battery-stats-engine-16.1.4.jar $out/share/java/
    # mkdir -p $out/share/java/lib
    # for f in lib/*.jar; do
    #   install -Dm644 $f $out/share/java/lib
    # done

    # mkdir -p $out/bin
    # mkdir -p $out/share
    # mkdir -p $out/share/pixmaps
    # cp driverlist.csv $out/share
    # cp admin/battery-stats.png $out/share/pixmaps

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "battery-stats";
      desktopName = "battery-stats";
      exec = "battery-stats";
      icon = "battery-stats";
    })
  ];

  meta = with lib; {
    description = "Battery-stats is a simple utility for collecting statistics about the laptop battery charge. Basically it will query ACPI at regular intervals and write the results to a log file.";
    license = licenses.gpl2;
    homepage = "https://github.com/petterreinholdtsen/battery-stats";
    changelog = "https://github.com/petterreinholdtsen/battery-stats/releases/tag/${version}";
    maintainers = with maintainers; [ guillaumematheron ];
    mainProgram = "battery-stats";
  };
}
