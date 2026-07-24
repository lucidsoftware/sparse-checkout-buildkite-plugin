#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
}

@test "converts a repository URL to the same mirror directory name as buildkite-agent" {
  run bash -c '. "$1"; git_mirror_dir_for_repository "$2"' \
    _ \
    "$PWD/lib/shared.bash" \
    "git@github.com:lucid-software-internal/main.git"

  assert_success
  assert_output "git-github-com-lucid-software-internal-main-git"
}

@test "resolves BUILDKITE_REPO_MIRROR when the agent already provided one" {
  local mirror_path="${BATS_TEST_TMPDIR}/provided-mirror"
  mkdir -p "${mirror_path}/objects"

  run env BUILDKITE_REPO_MIRROR="${mirror_path}" bash -c \
    '. "$1"; resolve_git_mirror "$2"; printf "%s\n" "$GIT_MIRROR_DIR"' \
    _ \
    "$PWD/lib/shared.bash" \
    "git@github.com:example/repo.git"

  assert_success
  assert_output "${mirror_path}"
}

@test "derives the existing mirror from BUILDKITE_GIT_MIRRORS_PATH" {
  local mirrors_path="${BATS_TEST_TMPDIR}/mirrors"
  local mirror_path="${mirrors_path}/git-github-com-example-repo-git"
  mkdir -p "${mirror_path}/objects"

  run env BUILDKITE_GIT_MIRRORS_PATH="${mirrors_path}" bash -c \
    '. "$1"; resolve_git_mirror "$2"; printf "%s\n" "$GIT_MIRROR_DIR"' \
    _ \
    "$PWD/lib/shared.bash" \
    "git@github.com:example/repo.git"

  assert_success
  assert_output "${mirror_path}"
}

@test "falls back cleanly when the derived mirror does not exist" {
  local mirrors_path="${BATS_TEST_TMPDIR}/mirrors"

  run env BUILDKITE_GIT_MIRRORS_PATH="${mirrors_path}" bash -c \
    '. "$1"; resolve_git_mirror "$2"' \
    _ \
    "$PWD/lib/shared.bash" \
    "git@github.com:example/repo.git"

  assert_failure
  assert_output --partial "No existing git mirror found"
}
