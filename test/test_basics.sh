#!/bin/sh

. $(dirname $0)/test_helper.sh

test_everything_passes() {
  result_pass debci batch
  status=$(debci status -l)
  assertEquals "pass" "$(echo "$status" | awk '{print($2)}' | uniq)"

  # check validity of debci-status format
  echo "$status" | grep -q '^ruby *pass$' || fail "invalid format:\n$status"
  echo "$status" | grep -q '^rake *pass$' || fail "invalid format:\n$status"
}

test_everything_fails() {
  result_fail debci batch
  status=$(debci status -l)
  assertEquals "fail" "$(echo "$status" | awk '{print($2)}' | uniq)"

  # check validity of debci-status format
  echo "$status" | grep -q '^ruby *fail$' || fail "invalid format:\n$status"
  echo "$status" | grep -q '^rake *fail$' || fail "invalid format:\n$status"
}

test_packages_without_runs_yet() {
  result_pass debci batch
  find $debci_data_basedir -type d -name rake | xargs rm -rf
  debci generate-index
  find $debci_data_basedir -name packages.json | xargs cat | json_pp -f json -t json > /dev/null
  assertEquals 0 $?
}

test_single_package() {
  echo "mypkg" > $debci_config_dir/whitelist
  result_pass debci batch
  assertEquals "mypkg pass" "$(debci status -l)"
}

# batch skips a package after it previously succeeded and there is no
# dependency change
test_batch_skip_after_result() {
  export DEBCI_FAKE_DEPS="foo 1.2.3"
  echo "mypkg" > $debci_config_dir/whitelist
  result_pass debci batch
  num_logs=$(ls $(status_dir_for_package mypkg)/*.autopkgtest.log | wc -l)
  assertEquals 1 $num_logs

  result_pass debci batch
  num_logs=$(ls $(status_dir_for_package mypkg)/*.autopkgtest.log | wc -l)
  assertEquals 1 $num_logs
}

# batch re-runs a package after it previously tmpfailed
test_batch_rerun_after_tmpfail() {
  export DEBCI_FAKE_DEPS="foo 1.2.3"
  echo "mypkg" > $debci_config_dir/whitelist
  result_tmpfail debci batch
  num_logs=$(ls $(status_dir_for_package mypkg)/*.autopkgtest.log | wc -l)
  assertEquals 1 $num_logs

  result_pass debci batch
  num_logs=$(ls $(status_dir_for_package mypkg)/*.autopkgtest.log | wc -l)
  assertEquals 2 $num_logs

  log=$(cat $(status_dir_for_package mypkg)/latest.log)
  echo "$log" | grep -iq 'retrying' || fail "log does not show retrying:\n$log"
  echo "$log" | grep -q 'changes.*dependenc' && fail "log claims dep change:\n$log"
}

# batch re-runs a package on changed dependencies
test_batch_rerun_dep_change() {
  export DEBCI_FAKE_DEPS="foo 1.2.3"
  echo "mypkg" > $debci_config_dir/whitelist
  result_pass debci batch
  num_logs=$(ls $(status_dir_for_package mypkg)/*.autopkgtest.log | wc -l)
  assertEquals 1 $num_logs

  export DEBCI_FAKE_DEPS="foo 1.2.4"
  result_pass debci batch
  num_logs=$(ls $(status_dir_for_package mypkg)/*.autopkgtest.log | wc -l)
  assertEquals 2 $num_logs

  log=$(cat $(status_dir_for_package mypkg)/latest.log)
  echo "$log" | grep -q 'changes.*dependenc' || fail "log does not show dep change:\n$log"
  echo "$log" | grep -q '^-foo 1.2.3' || fail "log does not show old dep:\n$log"
  echo "$log" | grep -q '^+foo 1.2.4' || fail "log does not show new dep:\n$log"
}

# batch runs a package without changes with --force
test_batch_force() {
  export DEBCI_FAKE_DEPS="foo 1.2.3"
  echo "mypkg" > $debci_config_dir/whitelist
  result_pass debci batch
  num_logs=$(ls $(status_dir_for_package mypkg)/*.autopkgtest.log | wc -l)
  assertEquals 1 $num_logs

  result_pass debci batch --force
  num_logs=$(ls $(status_dir_for_package mypkg)/*.autopkgtest.log | wc -l)
  assertEquals 2 $num_logs

  log=$(cat $(status_dir_for_package mypkg)/latest.log)
  echo "$log" | grep -iq 'forced.*for mypkg' || fail "log does not show 'forced' reason:\n$log"
  echo "$log" | grep -q 'changes.*dependenc' && fail "log claims dep change:\n$log"
}

. shunit2
