#!/usr/bin/env bats

@test "Terraform disponible" {
  run terraform version
  [ "$status" -eq 0 ]
}

@test "Helm disponible" {
  run helm version
  [ "$status" -eq 0 ]
}

@test "yamllint disponible" {
  run yamllint --version
  [ "$status" -eq 0 ]
}

@test "jq disponible" {
  run jq --version
  [ "$status" -eq 0 ]
}

@test "YAML Syntax (config)" {
  run yamllint config/
  [ "$status" -eq 0 ]
}

@test "YAML Syntax (blinkchamber)" {
  # Extract the YAML from the output of the script
  run awk '/^---/{f=1}f' rendered-blinkchamber.yaml > rendered.yaml
  [ "$status" -eq 0 ]
  run yamllint rendered.yaml
  [ "$status" -eq 0 ]
}

@test "Bash Syntax (scripts)" {
  run find scripts/ -name '*.sh' -exec bash -n {} \;
  [ "$status" -eq 0 ]
} 