setup_file() {
    load 'test_helper/common-setup'
    _common_setup
}

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    export INSTALLER_CONFIG_URL="${TEST_SERVER_URL}/${TEST_BASENAME}/#branch#/projects.json"
    export INSTALLER_SELF_URL="${TEST_SERVER_URL}/${TEST_BASENAME}/installer.sh"
    export INSTALLER_CONFIG_SCM='plain'

    # Ensure git user identity is set in case test environment doesn't have it
    git config --global user.name "Test User"
    git config --global user.email "test@example.com"

    # Allow local file protocol for cloning/updating submodules during tests
    git config --global protocol.file.allow always
}

@test "clone and update repository with submodules" {
    # 1. Create a dummy submodule source repo
    mkdir -p "$TEST_FILE_TMPDIR/submodule-source"
    pushd "$TEST_FILE_TMPDIR/submodule-source" > /dev/null
    git init
    git checkout -B master
    echo "submodule content v1" > file.txt
    git add file.txt
    git commit -m "initial submodule commit"
    popd > /dev/null

    # 2. Create a dummy superproject source repo
    mkdir -p "$TEST_FILE_TMPDIR/superproject-source"
    pushd "$TEST_FILE_TMPDIR/superproject-source" > /dev/null
    git init
    git checkout -B master
    echo "readme content" > README.md
    git add README.md
    git commit -m "initial superproject commit"
    git submodule add "$TEST_FILE_TMPDIR/submodule-source" my-submodule
    git commit -m "added submodule"
    popd > /dev/null

    # 3. Create the projects.json configuration file in current test execution dir
    cat <<EOF > "$TEST_FILE_TMPDIR/projects.json"
{
  "projects": [
    {
      "name": "my-project",
      "category": "generic",
      "default": "true",
      "urls": {
        "fetch": "$TEST_FILE_TMPDIR/superproject-source"
      },
      "branch": "master",
      "update": "true",
      "submodules": "true"
    }
  ]
}
EOF

    # 4. Run clone test (install command)
    cd "$TEST_FILE_TMPDIR"
    run installer.sh --yes --use-local-config install my-project

    assert_output --partial "Initializing submodules"
    [ "$status" -eq 0 ]
    [ -d "$TEST_FILE_TMPDIR/my-project/my-submodule" ]
    run cat "$TEST_FILE_TMPDIR/my-project/my-submodule/file.txt"
    assert_output "submodule content v1"

    # 5. Push a submodule change and update the superproject
    pushd "$TEST_FILE_TMPDIR/submodule-source" > /dev/null
    echo "submodule content v2" > file.txt
    git add file.txt
    git commit -m "updated submodule commit"
    popd > /dev/null

    pushd "$TEST_FILE_TMPDIR/superproject-source" > /dev/null
    pushd my-submodule > /dev/null
    git pull origin master
    popd > /dev/null
    git add my-submodule
    git commit -m "update submodule reference"
    popd > /dev/null

    # 6. Run update test
    run installer.sh --yes --use-local-config update

    assert_output --partial "Updating submodules"
    [ "$status" -eq 0 ]
    run cat "$TEST_FILE_TMPDIR/my-project/my-submodule/file.txt"
    assert_output "submodule content v2"
}

@test "do not update submodules if update is not allowed" {
    # 1. Create a dummy submodule source repo
    mkdir -p "$TEST_FILE_TMPDIR/sub-src2"
    pushd "$TEST_FILE_TMPDIR/sub-src2" > /dev/null
    git init
    git checkout -B master
    echo "sub v1" > file.txt
    git add file.txt
    git commit -m "initial commit"
    popd > /dev/null

    # 2. Create a dummy superproject source repo
    mkdir -p "$TEST_FILE_TMPDIR/super-src2"
    pushd "$TEST_FILE_TMPDIR/super-src2" > /dev/null
    git init
    git checkout -B master
    echo "readme" > README.md
    git add README.md
    git commit -m "initial commit"
    git submodule add "$TEST_FILE_TMPDIR/sub-src2" my-submodule
    git commit -m "add sub"
    popd > /dev/null

    # 3. Create the projects.json configuration file (update is false)
    cat <<EOF > "$TEST_FILE_TMPDIR/projects.json"
{
  "projects": [
    {
      "name": "my-project2",
      "category": "generic",
      "default": "true",
      "urls": {
        "fetch": "$TEST_FILE_TMPDIR/super-src2"
      },
      "branch": "master",
      "update": "false",
      "submodules": "true"
    }
  ]
}
EOF

    # 4. Run clone (install) - submodules should still be initialized
    cd "$TEST_FILE_TMPDIR"
    run installer.sh --yes --use-local-config install my-project2
    [ "$status" -eq 0 ]
    assert_output --partial "Initializing submodules"
    [ -d "$TEST_FILE_TMPDIR/my-project2/my-submodule" ]
    run cat "$TEST_FILE_TMPDIR/my-project2/my-submodule/file.txt"
    assert_output "sub v1"

    # 5. Push a submodule change and update the superproject
    pushd "$TEST_FILE_TMPDIR/sub-src2" > /dev/null
    echo "sub v2" > file.txt
    git add file.txt
    git commit -m "sub update"
    popd > /dev/null

    pushd "$TEST_FILE_TMPDIR/super-src2" > /dev/null
    pushd my-submodule > /dev/null
    git pull origin master
    popd > /dev/null
    git add my-submodule
    git commit -m "super update"
    popd > /dev/null

    # 6. Run update - submodules should NOT be updated because update is false
    run installer.sh --yes --use-local-config update
    [ "$status" -eq 0 ]
    refute_output --partial "Updating submodules"
    run cat "$TEST_FILE_TMPDIR/my-project2/my-submodule/file.txt"
    assert_output "sub v1"
}

teardown() {
    git config --global --unset protocol.file.allow || true
}

teardown_file() {
    kill "$(< "$TEST_FILE_TMPDIR/.test-server.pid")"
}
