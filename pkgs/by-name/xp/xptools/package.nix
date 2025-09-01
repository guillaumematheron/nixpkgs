{ lib
, stdenv
, fetchFromGitHub
, cmake
, ninja
, pkg-config
, expat
, proj
, freetype
, zlib
, libpng
, libjpeg
, libtiff
, libgeotiff
, shapelib
, curl
, jsoncpp
, glew
, libGL
, libGLU
, libglvnd
, fltk
, sqlite
, libsquish
}:

stdenv.mkDerivation rec {
  pname = "xptools";
  version = "2.6.0r2";

  # Replace with your repo/commit (or use fetchGit while iterating)
  src = fetchFromGitHub {
    owner = "X-Plane";
    repo = "xptools";
    rev = "da7f2d1ff6b518a3e48f93fd768b4aaff29408a8";
    hash = "sha256-fwxlpggPybtzK+PmEK3LkRChOw7ycJ1WMy3dZgTnwks=";
  };

  postUnpack = ''
    echo "sourceRoot=$sourceRoot"
    find "$sourceRoot" -maxdepth 2 -name CMakeLists.txt -print
  '';

  patches = [
    ./0001-fix-cmake.patch
  ];

  nativeBuildInputs = [ cmake ninja pkg-config ];

  buildInputs = [
    expat
    proj
    freetype
    zlib
    libpng
    libjpeg
    libtiff
    libgeotiff
    shapelib
    curl
    jsoncpp
    glew
    libGL
    libGLU
    libglvnd
    fltk
    sqlite
    libsquish
  ];

  # Some deps in nixpkgs does not ship a Config.cmake.
  # Until included in nixpkgs, inject a tiny config into CMAKE_PREFIX_PATH.
  preConfigure = ''
    export CXXFLAGS="$CXXFLAGS -Wno-error=format-security"

    cmake_shims=$TMPDIR/cmake-shims
    mkdir -p "$cmake_shims/GeoTIFF" "$cmake_shims/shapelib" "$cmake_shims/fltk" "$cmake_shims/glew" "$cmake_shims/egl" "$cmake_shims/opengl" "$cmake_shims/glu"

    cat > "$cmake_shims/GeoTIFF/GeoTIFFConfig.cmake" <<EOF
include_guard()
if(NOT TARGET GeoTIFF::GeoTIFF)
  add_library(GeoTIFF::GeoTIFF INTERFACE IMPORTED)
  set_target_properties(GeoTIFF::GeoTIFF PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${libgeotiff.dev}/include"
    INTERFACE_LINK_LIBRARIES "${libgeotiff}/lib/libgeotiff.so"
  )
endif()
set(GeoTIFF_FOUND TRUE)
EOF

    cat > "$cmake_shims/shapelib/shapelib-config.cmake" <<EOF
include_guard()
if(NOT TARGET shapelib::shp)
  add_library(shapelib::shp INTERFACE IMPORTED)
  set_target_properties(shapelib::shp PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${shapelib}/include"
    INTERFACE_LINK_LIBRARIES "${shapelib}/lib/libshp.so"
  )
endif()
set(shapelib_FOUND TRUE)
EOF

    # GLU shim (Conan-style glu -> CMake OpenGL::GLU)
    cat > "$cmake_shims/glu/glu-config.cmake" <<EOF
include_guard()
find_package(OpenGL REQUIRED)
if(NOT TARGET glu::glu)
  add_library(glu::glu INTERFACE IMPORTED)
  set_target_properties(glu::glu PROPERTIES
    INTERFACE_LINK_LIBRARIES OpenGL::GLU
  )
endif()
set(glu_FOUND TRUE)
EOF

    cat > "$cmake_shims/fltk/fltk-config.cmake" <<EOF
include_guard()
if(NOT TARGET fltk::fltk)
  add_library(fltk::fltk INTERFACE IMPORTED)
  set_target_properties(fltk::fltk PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${fltk}/include"
    INTERFACE_LINK_LIBRARIES "${fltk}/lib/libfltk.so"
  )
endif()
if(NOT TARGET fltk::gl)
  add_library(fltk::gl INTERFACE IMPORTED)
  set_target_properties(fltk::gl PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${fltk}/include"
    INTERFACE_LINK_LIBRARIES "${fltk}/lib/libfltk_gl.so"
  )
endif()
set(fltk_FOUND TRUE)
EOF

    cat > "$cmake_shims/glew/glew-config.cmake" <<EOF
include_guard()
if(NOT TARGET GLEW::glew_s)
  add_library(GLEW::glew_s INTERFACE IMPORTED)
  set_target_properties(GLEW::glew_s PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${glew.dev}/include"
    INTERFACE_LINK_LIBRARIES "${glew.out}/lib/libGLEW.so"
  )
endif()
set(GLEW_FOUND TRUE)
EOF

    cat > "$cmake_shims/egl/egl-config.cmake" <<EOF
include_guard()
find_package(OpenGL REQUIRED)
if(NOT TARGET egl::egl)
  add_library(egl::egl INTERFACE IMPORTED)
  set_target_properties(egl::egl PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${libglvnd.dev}/include"
    INTERFACE_LINK_LIBRARIES "${libglvnd}/lib/libEGL.so"
  )
endif()
set(egl_FOUND TRUE)
EOF

    cat > "$cmake_shims/opengl/opengl-config.cmake" <<'EOF'
include_guard()
find_package(OpenGL REQUIRED)
if(NOT TARGET opengl::opengl)
  add_library(opengl::opengl INTERFACE IMPORTED)
  set_target_properties(opengl::opengl PROPERTIES
    INTERFACE_LINK_LIBRARIES "OpenGL::OpenGL;OpenGL::GL;OpenGL::GLU"
  )
endif()
set(opengl_FOUND TRUE)
EOF

    export CMAKE_PREFIX_PATH="$cmake_shims''${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
  '';

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  # The project doesn’t have CMake install() rules,
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    # We’re in the build dir here; copy the executables that exist.
    for bin in WED ObjView DSFTool DDSTool genpath gen_roads GenTerrain gen_tiles make_fill_rules osm2shape osm_tile shape2xon SplitImage XGrinder; do
      if [ -x "./$bin" ]; then
        cp -v "./$bin" "$out/bin/"
      fi
    done
    runHook postInstall
  '';

  meta = with lib; {
    description = "X-Plane scenery/airport editing tools (ObjView, WED, etc.)";
    homepage = "https://developer.x-plane.com/tools/worldeditor/";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
    mainProgram = "WED";
  };
}

