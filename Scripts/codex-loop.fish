#!/usr/bin/env fish

function usage
    echo "Usage:"
    echo "  Scripts/codex-loop.fish --verify '<command>' --task '<prompt>' [options]"
    echo "  Scripts/codex-loop.fish --verify '<command>' --task-file <file> [options]"
    echo ""
    echo "Options:"
    echo "  --max-runs <n>        Number of Codex edit attempts. Default: 5"
    echo "  --sandbox <mode>      Codex sandbox mode. Default: workspace-write"
    echo "  --approval <policy>   Codex approval policy. Default: never"
    echo "  --model <model>       Codex model. Default: gpt-5.5"
    echo "  --reasoning <effort>  Reasoning effort. Default: xhigh"
    echo "  --standard-speed      Disable fast mode for this loop"
    echo "  --force               Improvement mode: run all max-runs even if verification passes"
    echo "  --limit-retry-interval <seconds>"
    echo "                         Sleep between likely Codex limit retries. Default: 3600"
    echo "  --limit-retry-max <n> Max hourly limit retries per Codex attempt. Default: 12"
    echo "  --no-limit-retry      Disable hourly retries for Codex limit/quota errors"
    echo "  --fallback-agent <agent>"
    echo "                         Agent to try when Codex is limit-blocked: claude | none. Default: claude"
    echo "  --fallback-claude-model <model>"
    echo "                         Claude fallback model. Default: claude-opus-4-8"
    echo "  --fallback-claude-effort <level>"
    echo "                         Claude fallback effort. Default: max"
    echo "  --fallback-claude-agent <agent>"
    echo "                         Claude fallback agent. Default: ultracode"
    echo "  --no-fallback-claude-agent"
    echo "                         Do not pass a Claude fallback agent"
    echo "  --fallback-claude-permission-mode <mode>"
    echo "                         Claude fallback permission mode. Default: bypassPermissions"
    echo "  --no-agent-fallback   Disable fallback to Claude when Codex is limit-blocked"
    echo "  --artifact-dir <dir>  Artifact root. Default: .codex-loop"
    echo "  --require-clean       Refuse to run if the Git worktree is dirty"
    echo "  --help                Show this help"
end

set verify_cmd ""
set task ""
set task_file ""
set max_runs 5
set sandbox "workspace-write"
set approval "never"
set model "gpt-5.5"
set reasoning_effort "xhigh"
set fast_mode 1
set force_run 0
set limit_retry_interval 3600
set limit_retry_max 12
set fallback_agent "claude"
set fallback_claude_model "claude-opus-4-8"
set fallback_claude_effort "max"
set fallback_claude_agent "ultracode"
set fallback_claude_permission_mode "bypassPermissions"
set artifact_root ".codex-loop"
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
        case --sandbox
            set i (math $i + 1)
            set sandbox $argv[$i]
        case --approval
            set i (math $i + 1)
            set approval $argv[$i]
        case --model
            set i (math $i + 1)
            set model $argv[$i]
        case --reasoning
            set i (math $i + 1)
            set reasoning_effort $argv[$i]
        case --standard-speed
            set fast_mode 0
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
        case --fallback-claude-model
            set i (math $i + 1)
            set fallback_claude_model $argv[$i]
        case --fallback-claude-effort
            set i (math $i + 1)
            set fallback_claude_effort $argv[$i]
        case --fallback-claude-agent
            set i (math $i + 1)
            set fallback_claude_agent $argv[$i]
        case --no-fallback-claude-agent
            set fallback_claude_agent ""
        case --fallback-claude-permission-mode
            set i (math $i + 1)
            set fallback_claude_permission_mode $argv[$i]
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
    echo "This loop expects a Git repository because codex exec protects non-Git directories by default." >&2
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

set attempt 1
while test $attempt -le $max_runs
    run_verifier pre $attempt
    set pre_status $status
    set last_verify_status $pre_status
    if test $pre_status -eq 0 -a $force_run -eq 0
        echo "Verification passed before Codex attempt $attempt."
        echo "Artifacts: $run_dir"
        exit 0
    end
    if test $pre_status -eq 0 -a $force_run -eq 1
        echo "Verification passed before Codex attempt $attempt, but --force is set; running Codex anyway."
    end

    set iter_dir "$run_dir/attempt-$attempt"
    set prompt_file "$iter_dir/codex-prompt.md"
    set codex_stdout "$iter_dir/codex.stdout"
    set codex_stderr "$iter_dir/codex.stderr"
    set codex_last "$iter_dir/codex-final.md"

    begin
        echo "# Codex loop attempt $attempt of $max_runs"
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

    set codex_args exec --sandbox "$sandbox" --cd "$repo_root" --output-last-message "$codex_last" -c "approval_policy=$approval"
    if test -n "$model"
        set codex_args $codex_args --model "$model"
    end
    if test -n "$reasoning_effort"
        set codex_args $codex_args -c "model_reasoning_effort=$reasoning_effort"
    end
    if test $fast_mode -eq 1
        set codex_args $codex_args -c "service_tier=fast" -c "features.fast_mode=true"
    end

    set codex_limit_retries 0
    while true
        set retry_suffix ""
        if test $codex_limit_retries -gt 0
            set retry_suffix ".retry-$codex_limit_retries"
        end
        set run_stdout "$iter_dir/codex$retry_suffix.stdout"
        set run_stderr "$iter_dir/codex$retry_suffix.stderr"

        if test $codex_limit_retries -gt 0
            echo "Rechecking Codex limit reset for attempt $attempt (retry $codex_limit_retries/$limit_retry_max)..."
        else
            echo "Running Codex attempt $attempt..."
        end
        echo "Streaming Codex logs. Saving stdout to $run_stdout and stderr to $run_stderr"

        env CODEX_LOOP_PROMPT_FILE="$prompt_file" CODEX_LOOP_STDOUT="$run_stdout" CODEX_LOOP_STDERR="$run_stderr" /bin/bash -c '
            "$@" < "$CODEX_LOOP_PROMPT_FILE" > >(tee "$CODEX_LOOP_STDOUT") 2> >(tee "$CODEX_LOOP_STDERR" >&2)
        ' codex-loop codex $codex_args -
        set codex_status $status
        cp "$run_stdout" "$codex_stdout"
        cp "$run_stderr" "$codex_stderr"
        echo $codex_status > "$iter_dir/codex.status"

        if test $codex_status -eq 0
            break
        end

        if test $limit_retry_max -gt 0; and is_codex_limit_error "$codex_stderr" "$codex_stdout"
            if test "$fallback_agent" = "claude"
                set fallback_suffix ""
                if test $codex_limit_retries -gt 0
                    set fallback_suffix ".retry-$codex_limit_retries"
                end
                set fallback_stdout "$iter_dir/fallback-claude$fallback_suffix.stdout"
                set fallback_stderr "$iter_dir/fallback-claude$fallback_suffix.stderr"
                set fallback_status_file "$iter_dir/fallback-claude$fallback_suffix.status"
                set claude_fallback_args --print --input-format text --output-format stream-json --include-partial-messages --verbose --permission-mode "$fallback_claude_permission_mode"

                if test -n "$fallback_claude_model"
                    set claude_fallback_args $claude_fallback_args --model "$fallback_claude_model"
                end
                if test -n "$fallback_claude_effort"
                    set claude_fallback_args $claude_fallback_args --effort "$fallback_claude_effort"
                end
                if test -n "$fallback_claude_agent"
                    set claude_fallback_args $claude_fallback_args --agent "$fallback_claude_agent"
                end

                echo "Codex appears limit-blocked. Trying Claude fallback for attempt $attempt..."
                echo "Streaming Claude fallback logs. Saving stdout to $fallback_stdout and stderr to $fallback_stderr"

                env CLAUDE_LOOP_PROMPT_FILE="$prompt_file" CLAUDE_LOOP_STDOUT="$fallback_stdout" CLAUDE_LOOP_STDERR="$fallback_stderr" /bin/bash -c '
                    "$@" < "$CLAUDE_LOOP_PROMPT_FILE" > >(tee "$CLAUDE_LOOP_STDOUT") 2> >(tee "$CLAUDE_LOOP_STDERR" >&2)
                ' codex-loop-fallback-claude claude $claude_fallback_args
                set fallback_status $status
                echo $fallback_status > "$fallback_status_file"

                if test $fallback_status -eq 0
                    echo "Claude fallback succeeded for attempt $attempt."
                    echo "fallback=claude" > "$iter_dir/agent-used.txt"
                    break
                end

                if is_claude_limit_error "$fallback_stderr" "$fallback_stdout"
                    echo "Claude fallback is also limit-blocked."
                else
                    echo "Claude fallback failed with status $fallback_status. See $fallback_stderr" >&2
                    echo "Artifacts: $run_dir" >&2
                    exit $fallback_status
                end
            end

            set codex_limit_retries (math $codex_limit_retries + 1)

            if test $codex_limit_retries -gt $limit_retry_max
                echo "Codex still appears limit-blocked after $limit_retry_max retries. See $codex_stderr" >&2
                echo "Artifacts: $run_dir" >&2
                exit $codex_status
            end

            begin
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Codex hit a likely limit/quota error on attempt $attempt."
                echo "status=$codex_status"
                echo "stderr=$run_stderr"
                echo "stdout=$run_stdout"
                echo "fallback_agent=$fallback_agent"
                echo "sleep_seconds=$limit_retry_interval"
                echo ""
            end >> "$iter_dir/limit-retries.log"

            echo "Both available agents appear limit-blocked. Sleeping $limit_retry_interval seconds before retry $codex_limit_retries/$limit_retry_max."
            sleep "$limit_retry_interval"
            continue
        end

        echo "Codex failed with status $codex_status. See $codex_stderr" >&2
        echo "Artifacts: $run_dir" >&2
        exit $codex_status
    end

    run_verifier post $attempt
    set post_status $status
    set last_verify_status $post_status
    if test $post_status -eq 0
        if test $force_run -eq 1
            echo "Verification passed after Codex attempt $attempt; continuing because --force is set."
        else
            echo "Verification passed after Codex attempt $attempt."
            echo "Artifacts: $run_dir"
            exit 0
        end
    else if test $force_run -eq 1
        echo "Verification still failing after Codex attempt $attempt; continuing because --force is set."
    end

    set attempt (math $attempt + 1)
end

echo "Artifacts: $run_dir"
if test $force_run -eq 1
    if test $last_verify_status -eq 0
        echo "Improvement loop completed all $max_runs Codex attempts with a passing final verifier."
        exit 0
    end

    echo "Improvement loop completed all $max_runs Codex attempts, but the final verifier is failing."
    exit 1
end

echo "Loop ended after $max_runs Codex attempts without a passing verification."
exit 1
