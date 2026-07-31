#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  HOOK_DIR="$PWD"
  WORK_DIR=""
}

teardown() {
  cd "$HOOK_DIR" 2>/dev/null || true
  if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
  unstub git 2>/dev/null || true
}

@test "Unshallow enabled and repo is shallow fetches even when alternates are configured" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_POST_CHECKOUT_UNSHALLOW="true"

  WORK_DIR="$(mktemp -d)"
  mkdir -p "${WORK_DIR}/.git/objects/info"
  echo "abc123" >"${WORK_DIR}/.git/shallow"
  echo "/var/lib/buildkite-agent/git-mirrors/repo/objects" >"${WORK_DIR}/.git/objects/info/alternates"
  cd "${WORK_DIR}"

  stub git \
    "rev-parse --is-shallow-repository : echo 'true'" \
    "fetch --tags --quiet --unshallow origin : echo 'git fetch unshallow with alternates'"

  run "${HOOK_DIR}/hooks/post-checkout"

  assert_success
  assert_output --partial 'git fetch unshallow with alternates'
  assert_output --partial 'Repository unshallowed successfully'
}

@test "Unshallow enabled and repo is shallow fetches history and tags quietly" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_POST_CHECKOUT_UNSHALLOW="true"

  stub git "rev-parse --is-shallow-repository : echo 'true'" \
           "fetch --tags --quiet --unshallow origin : [[ \"\$GIT_CONFIG_VALUE_0\" = \"0\" ]]; [[ \"\$GIT_CONFIG_VALUE_1\" = \"false\" ]]; [[ \"\$GIT_CONFIG_VALUE_2\" = \"false\" ]]; echo 'git fetch unshallow with tags quietly'"

  run "$HOOK_DIR"/hooks/post-checkout

  assert_success
  assert_output --partial 'Unshallowing repository'
  assert_output --partial 'git fetch unshallow with tags quietly'
  assert_output --partial 'Repository unshallowed successfully'
}

@test "Unshallow enabled and repo is not shallow skips unshallow" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_POST_CHECKOUT_UNSHALLOW="true"

  stub git "rev-parse --is-shallow-repository : echo 'false'"

  run "$HOOK_DIR"/hooks/post-checkout

  assert_success
  assert_output --partial 'Repository is not shallow, skipping unshallow'
}

@test "Unshallow not configured skips post-checkout operations" {
  run "$HOOK_DIR"/hooks/post-checkout

  assert_success
  refute_output --partial 'Unshallowing repository'
}

@test "Unshallow enabled but fetch fails exits with error" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_POST_CHECKOUT_UNSHALLOW="true"

  stub git "rev-parse --is-shallow-repository : echo 'true'" \
           "fetch --tags --quiet --unshallow origin : exit 1"

  run "$HOOK_DIR"/hooks/post-checkout

  assert_failure
  assert_output --partial 'Failed to unshallow repository'
}
