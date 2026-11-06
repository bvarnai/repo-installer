#!/usr/bin/env bash

_common_setup() {
    if [[ $(uname -s) == "Linux" ]]; then
        TEST_SERVER_EXECUTABLE="static-web-server/static-web-server"
    else
        TEST_SERVER_EXECUTABLE="static-web-server/static-web-server.exe"
    fi
    export TEST_SERVER_EXECUTABLE

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"

    TEST_FILE_TMPDIR="$BATS_FILE_TMPDIR"

    # redirect on GitHub
    if [[ -n "$GITHUB_WORKSPACE" ]]; then
        export TEST_FILE_TMPDIR="$GITHUB_WORKSPACE/../tmp"
        if [[ -d "$TEST_FILE_TMPDIR" ]]; then
            # delete any previous artifacts
            rm -rf "${TEST_FILE_TMPDIR}"
        fi
        mkdir -p "$TEST_FILE_TMPDIR"
    fi

    export TEST_FILE_TMPDIR

    # Isolate global git configuration to the temporary test directory
    export GIT_CONFIG_GLOBAL="$TEST_FILE_TMPDIR/.gitconfig"
    touch "$GIT_CONFIG_GLOBAL"
    git config --global user.name "Test User"
    git config --global user.email "test@example.com"

    # start configuration server
    $TEST_SERVER_EXECUTABLE --directory-listing --port 8787 --root ./conf &
    echo $! > "$TEST_FILE_TMPDIR/.test-server.pid"

    # change working directory to staging
    cd "$TEST_FILE_TMPDIR" || exit

    # stage installer to tmp (so we run on a copy!)
    cp "$DIR/../src/installer.sh" installer.sh

    # make executables visible to PATH
    PATH="$TEST_FILE_TMPDIR:$PATH"

    # helper to get the test name directory
    TEST_BASENAME="$( basename "$BATS_TEST_FILENAME" )"
    export TEST_BASENAME

    export TEST_SERVER_URL="http://localhost:8787"

}
