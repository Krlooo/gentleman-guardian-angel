# shellcheck shell=bash

Describe 'providers.sh command code support'
  Include "$LIB_DIR/providers.sh"

  Describe 'get_provider_info()'
    It 'returns info for commandcode'
      When call get_provider_info "commandcode"
      The output should include "Command Code"
    End

    It 'returns info for commandcode with model'
      When call get_provider_info "commandcode:claude-sonnet-5-5"
      The output should include "Command Code"
      The output should include "model: claude-sonnet-5-5"
    End
  End

  Describe 'get_commandcode_command()'
    It 'prefers the cmdc binary when available'
      cmdc() { return 0; }

      When call get_commandcode_command

      The status should be success
      The output should equal "cmdc"
    End

    It 'falls back to the cmd binary on non-Windows platforms'
      local test_bin original_path original_ostype
      test_bin=$(mktemp -d)
      original_path="$PATH"
      original_ostype="${OSTYPE:-}"
      printf '#!/bin/bash\nexit 0\n' > "$test_bin/cmd"
      chmod +x "$test_bin/cmd"
      unset -f cmdc
      OSTYPE="linux-gnu"
      PATH="$test_bin"

      When call get_commandcode_command

      The status should be success
      The output should equal "cmd"
      PATH="$original_path"
      OSTYPE="$original_ostype"
      rm -rf "$test_bin"
    End

    It 'never falls back to the Windows system shell'
      local test_bin original_path original_ostype
      test_bin=$(mktemp -d)
      original_path="$PATH"
      original_ostype="${OSTYPE:-}"
      printf '#!/bin/bash\nexit 0\n' > "$test_bin/cmd"
      chmod +x "$test_bin/cmd"
      unset -f cmdc
      OSTYPE="msys"
      PATH="$test_bin"

      When call get_commandcode_command

      The status should be failure
      The output should be blank
      PATH="$original_path"
      OSTYPE="$original_ostype"
      rm -rf "$test_bin"
    End
  End

  Describe 'validate_provider() - commandcode'
    It 'succeeds when the Command Code CLI is available'
      cmdc() { return 0; }

      When call validate_provider "commandcode"
      The status should be success
    End

    It 'fails with an install hint when the CLI is missing'
      local test_bin original_path original_ostype
      test_bin=$(mktemp -d)
      original_path="$PATH"
      original_ostype="${OSTYPE:-}"
      unset -f cmdc
      OSTYPE="linux-gnu"
      PATH="$test_bin"

      When call validate_provider "commandcode"

      The status should be failure
      The output should include "Command Code CLI not found"
      PATH="$original_path"
      OSTYPE="$original_ostype"
      rm -rf "$test_bin"
    End
  End

  Describe 'execute_commandcode()'
    cmdc() {
      if [[ "$1" != "-p" ]]; then
        echo "unexpected command code args: $*" >&2
        return 64
      fi
      shift
      if [[ "${1:-}" == "--model" ]]; then
        echo "Model: $2"
        shift 2
      fi
      if [[ "${1:-}" != "--output-format" || "${2:-}" != "text" ]]; then
        echo "missing output format: $*" >&2
        return 64
      fi
      cat
    }

    It 'sends the prompt through stdin with the default model'
      When call execute_commandcode "" "test prompt"
      The status should be success
      The output should include "test prompt"
    End

    It 'passes an explicit model through'
      When call execute_commandcode "claude-sonnet-5-5" "test prompt"
      The status should be success
      The output should include "Model: claude-sonnet-5-5"
      The output should include "test prompt"
    End

    It 'fails when the CLI is unavailable'
      local test_bin original_path original_ostype
      test_bin=$(mktemp -d)
      original_path="$PATH"
      original_ostype="${OSTYPE:-}"
      unset -f cmdc
      OSTYPE="linux-gnu"
      PATH="$test_bin"

      When call execute_commandcode "" "test prompt"

      The status should be failure
      The stderr should include "Command Code CLI not found"
      PATH="$original_path"
      OSTYPE="$original_ostype"
      rm -rf "$test_bin"
    End
  End

  Describe 'execute_provider() - commandcode'
    It 'dispatches to the Command Code CLI'
      cmdc() { cat; }

      When call execute_provider "commandcode" "dispatch prompt"
      The status should be success
      The output should include "dispatch prompt"
    End
  End

  Describe 'execute_provider_with_timeout() - commandcode'
    It 'runs commandcode under the timeout wrapper'
      local test_bin original_path
      test_bin=$(mktemp -d)
      original_path="$PATH"
      printf '#!/bin/bash\n/bin/cat\n' > "$test_bin/cmdc"
      chmod +x "$test_bin/cmdc"
      unset -f cmdc
      export GGA_NO_SPINNER=1
      export CI=true
      PATH="$test_bin:$original_path"

      When call execute_provider_with_timeout "commandcode" "timeout prompt" 10

      The status should be success
      The output should include "timeout prompt"
      The stderr should include "Waiting for Command Code"
      PATH="$original_path"
      rm -rf "$test_bin"
    End
  End
End
