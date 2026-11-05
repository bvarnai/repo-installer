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
}

create_mock_git_drev() {
    local mock_bin="$1"
    local exit_code="${2:-0}"
    cat <<EOF > "$mock_bin"
#!/usr/bin/env bash
if [[ "\$1" == "--version" ]]; then
    echo "git-drev version v1.0.0"
    exit 0
fi
if [[ "\$1" == "get" ]]; then
    if [[ "$exit_code" -ne 0 ]]; then
        echo "[git-drev] Error: simulated get failure" >&2
        exit $exit_code
    fi
    mkdir -p data
    echo "synced-payload-\$(git rev-parse --short HEAD)" > data/payload.txt
    exit 0
fi
exit 1
EOF
    chmod +x "$mock_bin"
}

@test "clone and update repository with .git-drev.yaml" {
    # 1. Create a mock git-drev binary
    mkdir -p "$TEST_FILE_TMPDIR/bin"
    create_mock_git_drev "$TEST_FILE_TMPDIR/bin/git-drev" 0
    export INSTALLER_GIT_DREV="$TEST_FILE_TMPDIR/bin/git-drev"

    # 2. Create a dummy git-drev metadata source repo
    mkdir -p "$TEST_FILE_TMPDIR/drev-source"
    pushd "$TEST_FILE_TMPDIR/drev-source" > /dev/null
    git init
    git checkout -B main
    cat <<EOF > .git-drev.yaml
workdir: data
remote:
  host: storage-server
  path: /srv/drev/test
EOF
    echo "/data" > .gitignore
    git add .git-drev.yaml .gitignore
    git commit -m '{"uuid":"11111111-1111-4111-8111-111111111111","seq":"1"}'
    local rev1
    rev1=$(git rev-parse --short HEAD)
    popd > /dev/null

    # 3. Create projects.json
    mkdir -p "$TEST_FILE_TMPDIR/ws1"
    cat <<EOF > "$TEST_FILE_TMPDIR/ws1/projects.json"
{
  "projects": [
    {
      "name": "drev-project",
      "category": "generic",
      "default": "true",
      "urls": {
        "fetch": "$TEST_FILE_TMPDIR/drev-source"
      },
      "branch": "main",
      "update": "true"
    }
  ]
}
EOF

    # 4. Run install
    cd "$TEST_FILE_TMPDIR/ws1"
    run installer.sh --yes --skip-self-update --use-local-config install drev-project

    [ "$status" -eq 0 ]
    assert_output --partial "git-drev repository detected at 'drev-project'"
    assert_output --partial "Fetching git-drev directory revision..."
    [ -f "$TEST_FILE_TMPDIR/ws1/drev-project/data/payload.txt" ]
    run cat "$TEST_FILE_TMPDIR/ws1/drev-project/data/payload.txt"
    assert_output "synced-payload-${rev1}"

    # 5. Add a new commit to source repo and run update
    pushd "$TEST_FILE_TMPDIR/drev-source" > /dev/null
    git commit --allow-empty -m '{"uuid":"22222222-2222-4222-8222-222222222222","seq":"2"}'
    local rev2
    rev2=$(git rev-parse --short HEAD)
    popd > /dev/null

    run installer.sh --yes --skip-self-update --use-local-config update

    [ "$status" -eq 0 ]
    assert_output --partial "git-drev repository detected at 'drev-project'"
    assert_output --partial "Fetching git-drev directory revision..."
    run cat "$TEST_FILE_TMPDIR/ws1/drev-project/data/payload.txt"
    assert_output "synced-payload-${rev2}"
}

@test "detect alternative .git-drev/config.yaml path" {
    mkdir -p "$TEST_FILE_TMPDIR/bin"
    create_mock_git_drev "$TEST_FILE_TMPDIR/bin/git-drev" 0
    export INSTALLER_GIT_DREV="$TEST_FILE_TMPDIR/bin/git-drev"

    mkdir -p "$TEST_FILE_TMPDIR/drev-alt-source/.git-drev"
    pushd "$TEST_FILE_TMPDIR/drev-alt-source" > /dev/null
    git init
    git checkout -B main
    cat <<EOF > .git-drev/config.yaml
workdir: data
remote:
  host: storage-server
  path: /srv/drev/test
EOF
    git add .git-drev/config.yaml
    git commit -m '{"uuid":"33333333-3333-4333-8333-333333333333","seq":"1"}'
    popd > /dev/null

    mkdir -p "$TEST_FILE_TMPDIR/ws2"
    cat <<EOF > "$TEST_FILE_TMPDIR/ws2/projects.json"
{
  "projects": [
    {
      "name": "drev-alt-project",
      "category": "generic",
      "default": "true",
      "urls": {
        "fetch": "$TEST_FILE_TMPDIR/drev-alt-source"
      },
      "branch": "main",
      "update": "true"
    }
  ]
}
EOF

    cd "$TEST_FILE_TMPDIR/ws2"
    run installer.sh --yes --skip-self-update --use-local-config install drev-alt-project

    [ "$status" -eq 0 ]
    assert_output --partial "git-drev repository detected at 'drev-alt-project'"
    assert_output --partial "Fetching git-drev directory revision..."
    [ -f "$TEST_FILE_TMPDIR/ws2/drev-alt-project/data/payload.txt" ]
}

@test "skip git-drev synchronization when --skip-git-drev is set" {
    mkdir -p "$TEST_FILE_TMPDIR/bin"
    create_mock_git_drev "$TEST_FILE_TMPDIR/bin/git-drev" 0
    export INSTALLER_GIT_DREV="$TEST_FILE_TMPDIR/bin/git-drev"

    mkdir -p "$TEST_FILE_TMPDIR/ws3"
    cat <<EOF > "$TEST_FILE_TMPDIR/ws3/projects.json"
{
  "projects": [
    {
      "name": "drev-skip-project",
      "category": "generic",
      "default": "true",
      "urls": {
        "fetch": "$TEST_FILE_TMPDIR/drev-source"
      },
      "branch": "main",
      "update": "true"
    }
  ]
}
EOF

    cd "$TEST_FILE_TMPDIR/ws3"
    run installer.sh --yes --skip-self-update --use-local-config --skip-git-drev install drev-skip-project

    [ "$status" -eq 0 ]
    assert_output --partial "Skipping git-drev synchronization for 'drev-skip-project'"
    refute_output --partial "Fetching git-drev directory revision..."
    [ ! -f "$TEST_FILE_TMPDIR/ws3/drev-skip-project/data/payload.txt" ]
}

@test "gracefully skip when git-drev binary is not available" {
    export INSTALLER_GIT_DREV="/nonexistent/git-drev"

    mkdir -p "$TEST_FILE_TMPDIR/ws4"
    cat <<EOF > "$TEST_FILE_TMPDIR/ws4/projects.json"
{
  "projects": [
    {
      "name": "drev-missing-bin",
      "category": "generic",
      "default": "true",
      "urls": {
        "fetch": "$TEST_FILE_TMPDIR/drev-source"
      },
      "branch": "main",
      "update": "true"
    }
  ]
}
EOF

    cd "$TEST_FILE_TMPDIR/ws4"
    run installer.sh --yes --skip-self-update --use-local-config install drev-missing-bin

    [ "$status" -eq 0 ]
    assert_output --partial "git-drev repository detected at 'drev-missing-bin'"
    assert_output --partial "git-drev configuration found, but git-drev is not installed. Skipping git-drev synchronization."
}

@test "log non-fatal error when git-drev get fails" {
    mkdir -p "$TEST_FILE_TMPDIR/bin"
    create_mock_git_drev "$TEST_FILE_TMPDIR/bin/git-drev-fail" 1
    export INSTALLER_GIT_DREV="$TEST_FILE_TMPDIR/bin/git-drev-fail"

    mkdir -p "$TEST_FILE_TMPDIR/ws5"
    cat <<EOF > "$TEST_FILE_TMPDIR/ws5/projects.json"
{
  "projects": [
    {
      "name": "drev-fail-project",
      "category": "generic",
      "default": "true",
      "urls": {
        "fetch": "$TEST_FILE_TMPDIR/drev-source"
      },
      "branch": "main",
      "update": "true"
    }
  ]
}
EOF

    cd "$TEST_FILE_TMPDIR/ws5"
    run installer.sh --yes --skip-self-update --use-local-config install drev-fail-project

    [ "$status" -eq 0 ]
    assert_output --partial "Fetching git-drev directory revision..."
    assert_output --partial "Failed to fetch git-drev directory revision"
}

teardown_file() {
    kill "$(< "$TEST_FILE_TMPDIR/.test-server.pid")"
}
