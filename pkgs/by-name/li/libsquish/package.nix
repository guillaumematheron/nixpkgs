{ lib
, stdenv
, fetchurl
, cmake
, ninja
}:

stdenv.mkDerivation rec {
  pname = "libsquish";
  version = "1.15";

  src = fetchurl {
    url = "https://downloads.sourceforge.net/project/libsquish/libsquish-${version}.tgz";
    sha256 = "sha256-YoeW7rpgiGYYOmHQgNRpZ8ndpnI7wKPsUjJMhdIUcmk=";
  };

  nativeBuildInputs = [ cmake ninja ];

  unpackPhase = "tar xzf $src";

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
  ];

  # Provide a minimal CMake config so find_package(libsquish) works
  postInstall = ''
    cmakeDir="$out/lib/cmake/libsquish"
    mkdir -p "$cmakeDir"
    cat > "$cmakeDir/libsquish-config.cmake" <<EOF
include_guard()
if(NOT TARGET libsquish::libsquish)
  add_library(libsquish::libsquish INTERFACE IMPORTED)
  set_target_properties(libsquish::libsquish PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "$out/include"
    INTERFACE_LINK_LIBRARIES "$out/lib/libsquish.so"
  )
endif()
set(libsquish_FOUND TRUE)
EOF
  '';

  meta = with lib; {
    description = "DXT/S3TC texture compression library";
    homepage = "https://sourceforge.net/projects/libsquish/";
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = with maintainers; [ ];
  };
}
