BUILD:="build"
SRC:="src"
ASSETS:="assets"
EMSCRIPTEN_SDK_DIR:="$HOME/tools/emsdk"

hr: 
    #!/bin/bash -eu
    OUT_DIR="{{BUILD}}/hot_reload"
    EXE="{{BUILD}}/game_hot_reload.bin"
    ROOT=$(odin root)
    DLL_EXT=".so"
    TEMP_DLL=$OUT_DIR/game_tmp.so
    EXTRA_LINKER_FLAGS="'-Wl,-rpath=\$ORIGIN/linux'"

    mkdir -p $OUT_DIR

    # Copy the linux libraries into the project automatically.
    if [ ! -d "$OUT_DIR/linux" ]; then
        mkdir -p $OUT_DIR/linux
        cp -r $ROOT/vendor/raylib/linux/libraylib*.so* $OUT_DIR/linux
    fi
    

    echo "Building game.so"
    odin build {{SRC}} -extra-linker-flags:"$EXTRA_LINKER_FLAGS" -define:RAYLIB_SHARED=true -build-mode:dll -out:$TEMP_DLL -strict-style -vet -debug

    # Need to use a temp file on Linux because it first writes an empty `game.so`,
    # which the game will load before it is actually fully written.
    mv $TEMP_DLL $OUT_DIR/game.so

    # If the executable is already running, then don't try to build and start it.
    # -f is there to make sure we match against full name, including .bin
    if pgrep -f $EXE > /dev/null; then
        echo "Hot reloading..."
        exit 0
    fi

    echo "Building $EXE"
    odin build {{SRC}}/main/hot_reload -out:$EXE -strict-style -vet -debug
    cp -R assets {{BUILD}}

    ./{{BUILD}}/game_hot_reload.bin

debug: 
    #!/bin/bash -eu
    OUT_DIR="{{BUILD}}/debug"
    MAIN_DIR="{{SRC}}/main/release"
    mkdir -p $OUT_DIR

    odin build $MAIN_DIR -out:$OUT_DIR/game_debug.bin -strict-style -vet -debug
    cp -R {{ASSETS}} $OUT_DIR
    echo "Debug build created in $OUT_DIR"

    ./{{BUILD}}/debug/game_debug.bin

release: 
    #!/bin/bash -eu
    OUT_DIR="{{BUILD}}/release"
    mkdir -p "$OUT_DIR"

    odin build {{SRC}}/main/release -out:$OUT_DIR/game_release.bin -strict-style -vet -no-bounds-check -o:speed
    cp -R {{ASSETS}} $OUT_DIR
    echo "Release build created in $OUT_DIR"

    ./{{BUILD}}/release/game_release.bin

web:
    #!/bin/bash -eu
    OUT_DIR="{{BUILD}}/web"
    mkdir -p $OUT_DIR

    export EMSDK_QUIET=1
    [[ -f "{{EMSCRIPTEN_SDK_DIR}}/emsdk_env.sh" ]] && . "{{EMSCRIPTEN_SDK_DIR}}/emsdk_env.sh"

    # Note RAYLIB_WASM_LIB=env.o -- env.o is an internal WASM object file. You can
    # see how RAYLIB_WASM_LIB is used inside <odin>/vendor/raylib/raylib.odin.
    #
    # The emcc call will be fed the actual raylib library file. That stuff will end
    # up in env.o
    #
    # Note that there is a rayGUI equivalent: -define:RAYGUI_WASM_LIB=env.o
    odin build {{SRC}}/main/web -target:js_wasm32 -build-mode:obj -define:RAYLIB_WASM_LIB=env.o -define:RAYGUI_WASM_LIB=env.o -vet -strict-style -out:$OUT_DIR/game

    ODIN_PATH=$(odin root)

    cp $ODIN_PATH/core/sys/wasm/js/odin.js $OUT_DIR

    files="$OUT_DIR/game.wasm.o ${ODIN_PATH}/vendor/raylib/wasm/libraylib.a ${ODIN_PATH}/vendor/raylib/wasm/libraygui.a"

    # index_template.html contains the javascript code that calls the procedures in
    # src/main/web.odin
    flags="-sUSE_GLFW=3 -sWASM_BIGINT -sWARN_ON_UNDEFINED_SYMBOLS=0 -sASSERTIONS --shell-file {{SRC}}/main/web/index_template.html --preload-file assets"

    # For debugging: Add `-g` to `emcc` (gives better error callstack in chrome)
    emcc -o $OUT_DIR/index.html $files $flags

    rm $OUT_DIR/game.wasm.o

    echo "Web build created in ${OUT_DIR}"

    cd ./{{BUILD}}/web && python3 -m http.server 6969
    