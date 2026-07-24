#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Uncomment to enable stub debugging
  # export CURL_STUB_DEBUG=/dev/tty

  # you can set variables common to all tests here
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS="default_path"
  export BUILDKITE_REPO_SSH_HOST="default_host"
  export BUILDKITE_COMMIT="dummy-commit-hash"
  export BUILDKITE_REPO="git@github.com:example/repo.git"
}

@test "Clone from the remote using an existing git mirror as a reference" {
  local plugin_dir="$PWD"
  local checkout_dir="${BATS_TEST_TMPDIR}/checkout"
  local mirror_dir="${BATS_TEST_TMPDIR}/mirror"
  mkdir -p "${checkout_dir}" "${mirror_dir}/objects"

  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_SKIP_SSH_KEYSCAN="true"
  export BUILDKITE_REPO_MIRROR="${mirror_dir}"

  stub git \
    "clone --no-checkout --reference ${mirror_dir} -v ${BUILDKITE_REPO} . : mkdir .git; echo 'reference mirror clone'" \
    "fetch origin ${BUILDKITE_COMMIT} : echo 'git fetch'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout ${BUILDKITE_COMMIT} : echo 'checkout'"

  cd "${checkout_dir}"
  run "${plugin_dir}"/hooks/checkout

  assert_success
  assert_output --partial "reference mirror clone"
  assert_output --partial "git fetch"
  assert_output --partial "Cloning repository using reference mirror ${mirror_dir}"

  unstub git
}

@test "Clean checkout does not reset a fresh clone before sparse checkout" {
  local plugin_dir="$PWD"
  local checkout_dir="${BATS_TEST_TMPDIR}/checkout"
  local mirror_dir="${BATS_TEST_TMPDIR}/mirror"
  mkdir -p "${checkout_dir}" "${mirror_dir}/objects"

  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_SKIP_SSH_KEYSCAN="true"
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="true"
  export BUILDKITE_REPO_MIRROR="${mirror_dir}"

  stub git \
    "clone --no-checkout --reference ${mirror_dir} -v ${BUILDKITE_REPO} . : mkdir .git; echo 'reference mirror clone'" \
    "fetch origin ${BUILDKITE_COMMIT} : echo 'git fetch'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout --force ${BUILDKITE_COMMIT} : echo 'checkout'" \
    "clean -ffxdq : echo 'git clean after checkout'"

  cd "${checkout_dir}"
  run "${plugin_dir}"/hooks/checkout

  assert_success
  refute_output --partial "resetting repository state"
  refute_output --partial "git reset"
  assert_output --partial "Clean checkout enabled - cleaning repository after checkout"
  assert_output --partial "git clean after checkout"

  unstub git
}

@test "Reuse an existing checkout and fetch the requested commit" {
  local plugin_dir="$PWD"
  local checkout_dir="${BATS_TEST_TMPDIR}/checkout"
  local mirror_dir="${BATS_TEST_TMPDIR}/mirror"
  mkdir -p "${checkout_dir}/.git" "${mirror_dir}/objects"

  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_SKIP_SSH_KEYSCAN="true"
  export BUILDKITE_REPO_MIRROR="${mirror_dir}"

  stub git \
    "clean -ffxdq : echo 'git clean'" \
    "fetch origin ${BUILDKITE_COMMIT} : echo 'git fetch'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout ${BUILDKITE_COMMIT} : echo 'checkout'"

  cd "${checkout_dir}"
  run "${plugin_dir}"/hooks/checkout

  assert_success
  assert_output --partial "git fetch"

  unstub git
}

@test "Skip ssh-keyscan when option provided" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_SKIP_SSH_KEYSCAN="true"

  stub git "clean \* : echo 'git clean'"
  stub git "fetch origin \* : echo 'git fetch'"
  stub git "sparse-checkout set \* \* : echo 'git sparse-checkout'" 
  stub git "checkout \* : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Skipped SSH keyscan'

  unstub git
}

@test "Run ssh-keyscan when no option provided" {
  unset BUILDKITE_PLUGIN_SPARSE_CHECKOUT_SKIP_SSH_KEYSCAN

  stub ssh-keyscan "\* : echo 'keyscan'"
  stub git "clean \* : echo 'git clean'"
  stub git "fetch origin \* : echo 'git fetch'"
  stub git "sparse-checkout set \* \* : echo 'git sparse-checkout'"
  stub git "checkout \* : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Scanning SSH keys'

  unstub git
  unstub ssh-keyscan
}

@test "Run ssh-keyscan when BUILDKITE_REPO_SSH_HOST is defined" {
  unset BUILDKITE_PLUGIN_SPARSE_CHECKOUT_SKIP_SSH_KEYSCAN
  export BUILDKITE_REPO_SSH_HOST="github.com"

  stub ssh-keyscan "\* : echo 'keyscan'"
  stub git "clean \* : echo 'git clean'"
  stub git "fetch origin \* : echo 'git fetch'"
  stub git "sparse-checkout set \* \* : echo 'git sparse-checkout'"
  stub git "checkout \* : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Scanning SSH keys'

  unstub git
  unstub ssh-keyscan
}

@test "Skip ssh-keyscan when BUILDKITE_REPO_SSH_HOST is unset" {
  unset BUILDKITE_REPO_SSH_HOST

  stub git "clean \* : echo 'git clean'"
  stub git "fetch origin \* : echo 'git fetch'"
  stub git "sparse-checkout set \* \* : echo 'git sparse-checkout'"
  stub git "checkout \* : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Skipped SSH keyscan'

  unstub git
}

@test "Respects BUILDKITE_GIT_FETCH_FLAGS in git fetch" {
  export BUILDKITE_GIT_FETCH_FLAGS="--prune --verbose"
  export BUILDKITE_COMMIT="HEAD"
  export BUILDKITE_BRANCH="main"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch --prune --verbose origin * : echo 'git fetch with flags'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch with flags'

  unstub ssh-keyscan
  unstub git
}

@test "Clean checkout disabled - uses normal git clean" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="false"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean -ffxdq : echo 'git clean normal'"
  stub git "fetch origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git clean normal'
  refute_output --partial 'Clean checkout enabled'

  unstub ssh-keyscan
  unstub git
}

@test "Clean checkout enabled performs aggressive cleanup" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="true"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "reset --hard HEAD : echo 'git reset hard'"
  stub git "clean -ffxdq : echo 'git clean aggressive'"
  stub git "fetch origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout --force * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Clean checkout enabled - resetting repository state'
  assert_output --partial 'git reset hard'
  assert_output --partial 'git clean aggressive'
  refute_output --partial 'git sparse-checkout disable'

  unstub ssh-keyscan
  unstub git
}

@test "Fetches pull request merge refspec when BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC is true" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="HEAD"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch origin refs/pull/123/merge : echo 'git fetch merge refspec'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout FETCH_HEAD : echo 'checkout fetch_head'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch merge refspec'
  assert_output --partial 'checkout fetch_head'

  unstub ssh-keyscan
  unstub git
}

@test "Fetches pull request merge refspec with known commit" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="456"
  export BUILDKITE_COMMIT="abc123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch origin refs/pull/456/merge : echo 'git fetch merge refspec'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout FETCH_HEAD : echo 'checkout fetch_head'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch merge refspec'
  assert_output --partial 'checkout fetch_head'

  unstub ssh-keyscan
  unstub git
}

@test "Retries missing merge ref before succeeding" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="abc123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep \
    "2 : true" \
    "5 : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch origin refs/pull/123/merge : echo 'git fetch merge refspec'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout FETCH_HEAD : echo 'checkout fetch_head'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'retrying in 2s'
  assert_output --partial 'retrying in 5s'
  assert_output --partial 'git fetch merge refspec'
  assert_output --partial 'checkout fetch_head'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Does not use merge refspec when BUILDKITE_PULL_REQUEST is false" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="false"
  export BUILDKITE_COMMIT="abc123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch origin abc123 : echo 'git fetch commit'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout abc123 : echo 'checkout commit'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch commit'
  assert_output --partial 'checkout commit'

  unstub ssh-keyscan
  unstub git
}

@test "Does not use merge refspec when flag is not set" {
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="abc123"
  unset BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch origin abc123 : echo 'git fetch commit'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout abc123 : echo 'checkout commit'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch commit'
  assert_output --partial 'checkout commit'

  unstub ssh-keyscan
  unstub git
}

@test "Clean checkout handles repository without HEAD gracefully" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="true"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "reset --hard HEAD : exit 1"
  stub git "clean -ffxdq : echo 'git clean'"
  stub git "fetch origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout --force * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Clean checkout enabled - resetting repository state'
  assert_output --partial 'git clean'
  refute_output --partial 'sparse-checkout disable'

  unstub ssh-keyscan
  unstub git
}
