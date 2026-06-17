#!/usr/bin/env fish

function usage
    echo "Usage:"
    echo "  Scripts/claude-loop.fish --verify '<command>' --task '<prompt>' [options]"
    echo "  Scripts/claude-loop.fish --verify '<command>' --task-file <file> [options]"
    echo ""
    echo "Options:"
    echo "  --max-runs <n>        Number of Claude edit attempts. Default: 5"
    echo "  --permission-mode <mode>"
    echo "                         Claude permission mode. Default: bypassPermissions"
    echo "  --model <model>       Claude model or alias. Default: claude-opus-4-8"
    echo "  --fallback-model <models>"
    echo "                         Comma-separated fallback model list. Default: unset"
    echo "  --effort <level>      Claude effort. Default: max"
    echo "  --agent <agent>       Claude Code agent. Default: ultracode"
    echo "  --no-agent            Do not pass a Claude Code agent"
    echo "  --max-budget-usd <n>  Optional Claude print-mode budget cap"
    echo "  --force               Improvement mode: run all max-runs even if verification passes"
    echo "  --limit-retry-interval <seconds>"
    echo "                         Sleep between likely Claude limit retries. Default: 3600"
    echo "  --limit-retry-max <n> Max hourly limit retries per Claude attempt. Default: 12"
    echo "  --no-limit-retry      Disable hourly retries for Claude limit/quota errors"
    echo "  --fallback-agent <agent>"
    echo "                         Agent to try when Claude is limit-blocked: codex | none. Default: codex"
    echo "  --fallback-codex-model <model>"
    echo "                         Codex fallback model. Default: gpt-5.5"
    echo "  --fallback-codex-reasoning <effort>"
    echo "                         Codex fallback reasoning effort. Default: xhigh"
    echo "  --fallback-codex-standard-speed"
    echo "                         Disable Codex fast mode for fallback"
    echo "  --no-agent-fallback   Disable fallback to Codex when Claude is limit-blocked"
    echo "  --artifact-dir <dir>  Artifact root. Default: .claude-loop"
    echo "  --require-clean       Refuse to run if the Git worktree is dirty"
    echo "  --help                Show this help"
end

set verify_cmd ""
set task ""
set task_file ""
set max_runs 5
set permission_mode "bypassPermissions"
set model "claude-opus-4-8"
set fallback_model ""
set effort "max"
set claude_agent "ultracode"
set max_budget_usd ""
set force_run 0
set limit_retry_interval 3600
set limit_retry_max 12
set fallback_agent "codex"
set fallback_codex_model "gpt-5.5"
set fallback_codex_reasoning "xhigh"
set fallback_codex_fast_mode 1
set artifact_root ".claude-loop"
set require_clean 0
set last_verify_status 1

set i 1
while test $i -le (count $argv)
    set arg $argv[$i]
    switch $arg
        case --verify
            set i (math $i + 1)
            set verify_cmd $argv[$i]
        case --task
            set i (math $i + 1)
            set task $argv[$i]
        case --task-file
            set i (math $i + 1)
            set task_file $argv[$i]
        case --max-runs
            set i (math $i + 1)
            set max_runs $argv[$i]
        case --permission-mode
            set i (math $i + 1)
            set permission_mode $argv[$i]
        case --model
            set i (math $i + 1)
            set model $argv[$i]
        case --fallback-model
            set i (math $i + 1)
            set fallback_model $argv[$i]
        case --effort
            set i (math $i + 1)
            set effort $argv[$i]
        case --agent
            set i (math $i + 1)
            set claude_agent $argv[$i]
        case --no-agent
            set claude_agent ""
        case --max-budget-usd
            set i (math $i + 1)
            set max_budget_usd $argv[$i]
        case --force
            set force_run 1
        case --limit-retry-interval
            set i (math $i + 1)
            set limit_retry_interval $argv[$i]
        case --limit-retry-max
            set i (math $i + 1)
            set limit_retry_max $argv[$i]
        case --no-limit-retry
            set limit_retry_max 0
        case --fallback-agent
            set i (math $i + 1)
            set fallback_agent $argv[$i]
        case --fallback-codex-model
            set i (math $i + 1)
            set fallback_codex_model $argv[$i]
        case --fallback-codex-reasoning
            set i (math $i + 1)
            set fallback_codex_reasoning $argv[$i]
        case --fallback-codex-standard-speed
            set fallback_codex_fast_mode 0
        case --no-agent-fallback
            set fallback_agent "none"
        case --artifact-dir
            set i (math $i + 1)
            set artifact_root $argv[$i]
        case --require-clean
            set require_clean 1
        case --help -h
            usage
            exit 0
        case '*'
            echo "Unknown argument: $arg" >&2
            usage >&2
            exit 2
    end
    set i (math $i + 1)
end

if test -z "$verify_cmd"
    echo "Missing --verify command" >&2
    usage >&2
    exit 2
end

if test -n "$task_file"
    if not test -f "$task_file"
        echo "Task file not found: $task_file" >&2
        exit 2
    end
    set task (string collect < "$task_file")
end

if test -z "$task"
    echo "Missing --task or --task-file" >&2
    usage >&2
    exit 2
end

set repo_root (git rev-parse --show-toplevel 2>/dev/null)
if test $status -ne 0
    echo "This loop expects a Git repository." >&2
    exit 2
end

cd "$repo_root"

if test $require_clean -eq 1
    git diff --quiet
    set unstaged_status $status
    git diff --cached --quiet
    set staged_status $status
    set untracked (git ls-files --others --exclude-standard)
    if test $unstaged_status -ne 0 -o $staged_status -ne 0 -o (count $untracked) -ne 0
        echo "Refusing to run because the worktree is dirty and --require-clean was set." >&2
        exit 2
    end
else
    git diff --quiet
    set unstaged_status $status
    git diff --cached --quiet
    set staged_status $status
    set untracked (git ls-files --others --exclude-standard)
    if test $unstaged_status -ne 0 -o $staged_status -ne 0 -o (count $untracked) -ne 0
        echo "Warning: worktree has existing changes. The loop will edit on top of the current state." >&2
    end
end

set run_id (date '+%Y%m%d-%H%M%S')
set run_dir "$artifact_root/runs/$run_id"
mkdir -p "$run_dir"

function run_verifier
    set phase $argv[1]
    set attempt $argv[2]
    set iter_dir "$run_dir/attempt-$attempt"
    mkdir -p "$iter_dir"

    set -gx CODEX_LOOP_ARTIFACT_DIR "$iter_dir/$phase"
    mkdir -p "$CODEX_LOOP_ARTIFACT_DIR"

    echo "Running verifier ($phase, attempt $attempt): $verify_cmd"
    fish -lc "$verify_cmd" > "$iter_dir/$phase.verify.stdout" 2> "$iter_dir/$phase.verify.stderr"
    set verify_status $status
    echo $verify_status > "$iter_dir/$phase.verify.status"
    return $verify_status
end

function is_claude_limit_error
    set stderr_file $argv[1]
    set stdout_file $argv[2]
    set pattern '(rate.?limit|usage.?limit|quota|too many requests|429|capacity|temporarily unavailable|overloaded|limit.*reset|credit|insufficient_quota|maximum.*tokens|exceeded.*limit|billing)'

    if test -f "$stderr_file"
        if grep -Eiq "$pattern" "$stderr_file"
            return 0
        end
    end

    if test -f "$stdout_file"
        if grep -Eiq "$pattern" "$stdout_file"
            return 0
        end
    end

    return 1
end

function is_codex_limit_error
    set stderr_file $argv[1]
    set stdout_file $argv[2]
    set pattern '(rate.?limit|usage.?limit|quota|too many requests|429|capacity|temporarily unavailable|limit.*reset|credit|insufficient_quota)'

    if test -f "$stderr_file"
        if grep -Eiq "$pattern" "$stderr_file"
            return 0
        end
    end

    if test -f "$stdout_file"
        if grep -Eiq "$pattern" "$stdout_file"
            return 0
        end
    end

    return 1
end

set attempt 1
while test $attempt -le $max_runs
    run_verifier pre $attempt
    set pre_status $status
    set last_verify_status $pre_status
    if test $pre_status -eq 0 -a $force_run -eq 0
        echo "Verification passed before Claude attempt $attempt."
        echo "Artifacts: $run_dir"
        exit 0
    end
    if test $pre_status -eq 0 -a $force_run -eq 1
        echo "Verification passed before Claude attempt $attempt, but --force is set; running Claude anyway."
    end

    set iter_dir "$run_dir/attempt-$attempt"
    set prompt_file "$iter_dir/claude-prompt.md"
    set claude_stdout "$iter_dir/claude.stdout"
    set claude_stderr "$iter_dir/claude.stderr"

    begin
        echo "# Claude loop attempt $attempt of $max_runs"
        echo ""
        echo "Repository: $repo_root"
        echo ""
        echo "## Task"
        echo ""
        echo "$task"
        echo ""
        if test $pre_status -eq 0
            echo "## Passing verification baseline"
        else
            echo "## Failed verification"
        end
        echo ""
        echo "Command:"
        echo ""
        echo '```text'
        echo "$verify_cmd"
        echo '```'
        echo ""
        if test $pre_status -eq 0
            echo "Artifacts from the passing baseline:"
        else
            echo "Artifacts from the failed gate:"
        end
        echo ""
        echo "- $iter_dir/pre/summary.md"
        echo "- $iter_dir/pre/build.log"
        echo "- $iter_dir/pre/processor-tests.log"
        echo "- $iter_dir/pre/quality-score.md"
        echo "- $iter_dir/pre/latency-samples.tsv"
        echo "- $iter_dir/pre/recent-app-logs.txt"
        if test $attempt -gt 1
            set previous_attempt (math $attempt - 1)
            echo ""
            echo "Previous attempt comparison artifacts:"
            echo ""
            echo "- $run_dir/attempt-$previous_attempt/post/summary.md"
            echo "- $run_dir/attempt-$previous_attempt/post/quality-score.md"
            echo "- $run_dir/attempt-$previous_attempt/post/latency-samples.tsv"
        end
        echo ""
        echo "Instructions:"
        echo ""
        echo "- Read AGENTS.md and CLAUDE.md before editing."
        echo "- Read the verifier artifacts before editing."
        if test $force_run -eq 1
            echo "- This is an improvement loop, not just a fix loop."
            echo "- First identify missing or weak scenarios in the current tests/score artifacts."
            echo "- Compare with the previous attempt's post-score when available."
            echo "- Add or adjust deterministic tests/benchmarks for those scenarios before changing production behavior."
            echo "- Then make the smallest focused behavior improvement that should improve the score or coverage."
            echo "- Do not weaken existing expectations just to keep the verifier green."
        else
            echo "- Make the smallest focused change that can make the gate pass."
            echo "- Add or adjust deterministic tests for behavior changes."
        end
        echo "- Do not commit changes."
        echo "- Do not hardcode secrets."
        echo "- Respect existing dirty worktree changes."
    end > "$prompt_file"

    set claude_args --print --input-format text --output-format stream-json --include-partial-messages --verbose --permission-mode "$permission_mode"
    if test -n "$model"
        set claude_args $claude_args --model "$model"
    end
    if test -n "$fallback_model"
        set claude_args $claude_args --fallback-model "$fallback_model"
    end
    if test -n "$effort"
        set claude_args $claude_args --effort "$effort"
    end
    if test -n "$claude_agent"
        set claude_args $claude_args --agent "$claude_agent"
    end
    if test -n "$max_budget_usd"
        set claude_args $claude_args --max-budget-usd "$max_budget_usd"
    end

    set claude_limit_retries 0
    while true
        set retry_suffix ""
        if test $claude_limit_retries -gt 0
            set retry_suffix ".retry-$claude_limit_retries"
        end
        set run_stdout "$iter_dir/claude$retry_suffix.stdout"
        set run_stderr "$iter_dir/claude$retry_suffix.stderr"

        if test $claude_limit_retries -gt 0
            echo "Rechecking Claude limit reset for attempt $attempt (retry $claude_limit_retries/$limit_retry_max)..."
        else
            echo "Running Claude attempt $attempt..."
        end
        echo "Streaming Claude logs. Saving stdout to $run_stdout and stderr to $run_stderr"

        env CLAUDE_LOOP_PROMPT_FILE="$prompt_file" CLAUDE_LOOP_STDOUT="$run_stdout" CLAUDE_LOOP_STDERR="$run_stderr" /bin/bash -c '
            "$@" < "$CLAUDE_LOOP_PROMPT_FILE" > >(tee "$CLAUDE_LOOP_STDOUT") 2> >(tee "$CLAUDE_LOOP_STDERR" >&2)
        ' claude-loop claude $claude_args
        set claude_status $status
        cp "$run_stdout" "$claude_stdout"
        cp "$run_stderr" "$claude_stderr"
        echo $claude_status > "$iter_dir/claude.status"

        if test $claude_status -eq 0
            break
        end

        if test $limit_retry_max -gt 0; and is_claude_limit_error "$claude_stderr" "$claude_stdout"
            if test "$fallback_agent" = "codex"
                set fallback_suffix ""
                if test $claude_limit_retries -gt 0
                    set fallback_suffix ".retry-$claude_limit_retries"
                end
                set fallback_stdout "$iter_dir/fallback-codex$fallback_suffix.stdout"
                set fallback_stderr "$iter_dir/fallback-codex$fallback_suffix.stderr"
                set fallback_last "$iter_dir/fallback-codex$fallback_suffix-final.md"
                set fallback_status_file "$iter_dir/fallback-codex$fallback_suffix.status"
                set codex_fallback_args exec --sandbox workspace-write --cd "$repo_root" --output-last-message "$fallback_last" -c approval_policy=never

                if test -n "$fallback_codex_model"
                    set codex_fallback_args $codex_fallback_args --model "$fallback_codex_model"
                end
                if test -n "$fallback_codex_reasoning"
                    set codex_fallback_args $codex_fallback_args -c "model_reasoning_effort=$fallback_codex_reasoning"
                end
                if test $fallback_codex_fast_mode -eq 1
                    set codex_fallback_args $codex_fallback_args -c service_tier=fast -c features.fast_mode=true
                end

                echo "Claude appears limit-blocked. Trying Codex fallback for attempt $attempt..."
                echo "Streaming Codex fallback logs. Saving stdout to $fallback_stdout and stderr to $fallback_stderr"

                env CODEX_LOOP_PROMPT_FILE="$prompt_file" CODEX_LOOP_STDOUT="$fallback_stdout" CODEX_LOOP_STDERR="$fallback_stderr" /bin/bash -c '
                    "$@" < "$CODEX_LOOP_PROMPT_FILE" > >(tee "$CODEX_LOOP_STDOUT") 2> >(tee "$CODEX_LOOP_STDERR" >&2)
                ' claude-loop-fallback-codex codex $codex_fallback_args -
                set fallback_status $status
                echo $fallback_status > "$fallback_status_file"

                if test $fallback_status -eq 0
                    echo "Codex fallback succeeded for attempt $attempt."
                    echo "fallback=codex" > "$iter_dir/agent-used.txt"
                    break
                end

                if is_codex_limit_error "$fallback_stderr" "$fallback_stdout"
                    echo "Codex fallback is also limit-blocked."
                else
                    echo "Codex fallback failed with status $fallback_status. See $fallback_stderr" >&2
                    echo "Artifacts: $run_dir" >&2
                    exit $fallback_status
                end
            end

            set claude_limit_retries (math $claude_limit_retries + 1)

            if test $claude_limit_retries -gt $limit_retry_max
                echo "Claude still appears limit-blocked after $limit_retry_max retries. See $claude_stderr" >&2
                echo "Artifacts: $run_dir" >&2
                exit $claude_status
            end

            begin
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude hit a likely limit/quota error on attempt $attempt."
                echo "status=$claude_status"
                echo "stderr=$run_stderr"
                echo "stdout=$run_stdout"
                echo "fallback_agent=$fallback_agent"
                echo "sleep_seconds=$limit_retry_interval"
                echo ""
            end >> "$iter_dir/limit-retries.log"

            echo "Both available agents appear limit-blocked. Sleeping $limit_retry_interval seconds before retry $claude_limit_retries/$limit_retry_max."
            sleep "$limit_retry_interval"
            continue
        end

        echo "Claude failed with status $claude_status. See $claude_stderr" >&2
        echo "Artifacts: $run_dir" >&2
        exit $claude_status
    end

    run_verifier post $attempt
    set post_status $status
    set last_verify_status $post_status
    if test $post_status -eq 0
        if test $force_run -eq 1
            echo "Verification passed after Claude attempt $attempt; continuing because --force is set."
        else
            echo "Verification passed after Claude attempt $attempt."
            echo "Artifacts: $run_dir"
            exit 0
        end
    else if test $force_run -eq 1
        echo "Verification still failing after Claude attempt $attempt; continuing because --force is set."
    end

    set attempt (math $attempt + 1)
end

echo "Artifacts: $run_dir"
if test $force_run -eq 1
    if test $last_verify_status -eq 0
        echo "Claude improvement loop completed all $max_runs attempts with a passing final verifier."
        exit 0
    end

    echo "Claude improvement loop completed all $max_runs attempts, but the final verifier is failing."
    exit 1
end

echo "Loop ended after $max_runs Claude attempts without a passing verification."
exit 1
