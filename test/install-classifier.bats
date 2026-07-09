
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
}

@test "install project with default classifier" {
    # Default classifier for Linux should append "-linux" before ".git"
    run installer.sh --yes install project1

    assert_output --partial "Repository fetch URL 'http://localhost:8787/install-classifier.bats/project1-linux.git'"
    assert_output --partial "[installer] Now at commit"
    [ "$status" -eq 0 ]
}

@test "install project with custom classifier hook (command override)" {
    # Set custom classifier hook via INSTALLER_CLASSIFIER env variable
    custom_classifier() {
        echo "custom"
    }
    export -f custom_classifier
    export INSTALLER_CLASSIFIER="custom_classifier"
    run installer.sh --yes install project2

    assert_output --partial "Repository fetch URL 'http://localhost:8787/install-classifier.bats/project2-custom.git'"
    assert_output --partial "[installer] Now at commit"
    [ "$status" -eq 0 ]
}

@test "install project with custom classifier hook replacing placeholder pattern" {
    # Set custom classifier hook via INSTALLER_CLASSIFIER env variable
    custom_classifier() {
        echo "custom"
    }
    export -f custom_classifier
    export INSTALLER_CLASSIFIER="custom_classifier"
    run installer.sh --yes install project3

    assert_output --partial "Repository fetch URL 'http://localhost:8787/install-classifier.bats/project3-custom.git'"
    assert_output --partial "[installer] Now at commit"
    [ "$status" -eq 0 ]
}

teardown_file() {
    kill "$(< "$TEST_FILE_TMPDIR/.test-server.pid")"
}
