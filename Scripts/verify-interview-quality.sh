#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

ARTIFACT_DIR="${CODEX_LOOP_ARTIFACT_DIR:-.codex-loop/latest}"
RUN_LIVE_CLASSIFICATION="${IM_RUN_LIVE_CLASSIFICATION:-0}"
RUN_AUDIO_SMOKE="${IM_RUN_AUDIO_SMOKE:-0}"
START_APP="${IM_START_APP:-0}"
AUDIO_STRICT="${IM_AUDIO_STRICT:-0}"
AUDIO_FIXTURE="${IM_AUDIO_FIXTURE:-question.aiff}"
AUDIO_WARMUP_SECONDS="${IM_AUDIO_WARMUP_SECONDS:-2}"
AUDIO_SETTLE_SECONDS="${IM_AUDIO_SETTLE_SECONDS:-8}"
AUDIO_AUTO_START_INTERVIEW="${IM_AUTO_START_INTERVIEW:-1}"

mkdir -p "$ARTIFACT_DIR"

SUMMARY="$ARTIFACT_DIR/summary.md"
: > "$SUMMARY"

STATUS=0

append_summary() {
    printf '%s\n' "$*" >> "$SUMMARY"
}

run_step() {
    local name="$1"
    shift
    local log_file="$ARTIFACT_DIR/${name}.log"

    append_summary "## ${name}"
    append_summary ""
    append_summary '```text'
    append_summary "$*"
    append_summary '```'
    append_summary ""

    "$@" > "$log_file" 2>&1
    local code=$?

    if [[ $code -eq 0 ]]; then
        append_summary "status: pass"
    else
        append_summary "status: fail (${code})"
        STATUS=1
    fi

    append_summary "log: ${log_file}"
    append_summary ""
    return $code
}

collect_logs() {
    if [[ -f interview_debug.log ]]; then
        cp interview_debug.log "$ARTIFACT_DIR/interview_debug.log"
    fi

    if [[ -f /tmp/interviewmaster.out ]]; then
        cp /tmp/interviewmaster.out "$ARTIFACT_DIR/interviewmaster.out"
    fi

    if [[ -f "$HOME/Documents/stealth_log.txt" ]]; then
        cp "$HOME/Documents/stealth_log.txt" "$ARTIFACT_DIR/stealth_log.txt" 2>/dev/null || true
    fi

    {
        echo "## Recent app debug log"
        if [[ -f interview_debug.log ]]; then
            tail -n 240 interview_debug.log
        else
            echo "interview_debug.log not found"
        fi
        echo
        echo "## Recent launch log"
        if [[ -f /tmp/interviewmaster.out ]]; then
            tail -n 240 /tmp/interviewmaster.out
        else
            echo "/tmp/interviewmaster.out not found"
        fi
    } > "$ARTIFACT_DIR/recent-app-logs.txt"
}

extract_latency_samples() {
    local samples="$ARTIFACT_DIR/latency-samples.tsv"
    : > "$samples"

    if [[ ! -f "$ARTIFACT_DIR/recent-app-logs.txt" ]]; then
        return
    fi

    awk '
    BEGIN {
        print "sample\tcard_start_ms\tfirst_answer_text_ms\tanswer_complete_ms\tcard_to_first_text_ms"
        sample = 0
        card = ""
        first = ""
        complete = ""
        start_ts = -1
        min_useful_chars = 12
    }

    function ts_ms(line, t, parts, secparts) {
        if (match(line, /[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9][0-9][0-9]/)) {
            t = substr(line, RSTART, RLENGTH)
            split(t, parts, ":")
            split(parts[3], secparts, ".")
            return ((parts[1] * 3600 + parts[2] * 60 + secparts[1]) * 1000 + secparts[2])
        }
        return -1
    }

    function chunk_chars(line, raw) {
        if (match(line, /total: [0-9]+ chars/)) {
            raw = substr(line, RSTART, RLENGTH)
            gsub(/[^0-9]/, "", raw)
            return raw + 0
        }
        if (match(line, /processorDidReceiveAnswerChunk: [0-9]+ chars/)) {
            raw = substr(line, RSTART, RLENGTH)
            gsub(/[^0-9]/, "", raw)
            return raw + 0
        }
        return -1
    }

    function emit() {
        if (card != "" || first != "" || complete != "") {
            sample += 1
            delta = ""
            if (card != "" && first != "") {
                delta = first - card
            }
            print sample "\t" card "\t" first "\t" complete "\t" delta
        }
        card = ""
        first = ""
        complete = ""
        start_ts = -1
    }

    /processorDidStartStreaming:/ || /Calling processorDidStartStreaming/ {
        if (card != "" && complete != "") {
            emit()
        }
        if (match($0, /(latency|cardStart)=[0-9]+ms/)) {
            raw = substr($0, RSTART, RLENGTH)
            gsub(/[^0-9]/, "", raw)
            card = raw + 0
            start_ts = ts_ms($0)
        }
    }

    (/Chunk received/ || /chunk received/ || /processorDidReceiveAnswerChunk:/) && card != "" && first == "" {
        chars = chunk_chars($0)
        if (chars >= 0 && chars < min_useful_chars) {
            next
        }
        chunk_ts = ts_ms($0)
        if (start_ts >= 0 && chunk_ts >= 0) {
            first = card + (chunk_ts - start_ts)
        }
    }

    /[Aa]nswer complete \([0-9]+ms\)/ {
        if (match($0, /[Aa]nswer complete \([0-9]+ms\)/)) {
            raw = substr($0, RSTART, RLENGTH)
            gsub(/[^0-9]/, "", raw)
            complete = raw + 0
            emit()
        }
    }

    /processorDidFinishAnswer:/ && /total=[0-9]+ms/ {
        if (match($0, /total=[0-9]+ms/)) {
            raw = substr($0, RSTART, RLENGTH)
            gsub(/[^0-9]/, "", raw)
            if (card != "" || first != "") {
                complete = raw + 0
                emit()
            }
        }
    }

    END {
        if (card != "" || first != "") {
            emit()
        }
    }
    ' "$ARTIFACT_DIR/recent-app-logs.txt" > "$samples"
}

write_quality_score() {
    local report="$ARTIFACT_DIR/quality-score.md"
    local processor_passed=""
    local processor_failed=""
    local processor_total=""
    local processor_percent=""
    local live_passed=""
    local live_total=""
    local live_percent=""
    local audio_markers="0"
    local latency_samples="0"
    local best_first_text=""
    local latest_first_text=""
    local latest_card_start=""
    local latest_complete=""
    local latest_card_to_first=""
    local max_first_text=""
    local over_target_count=""

    if [[ -f "$ARTIFACT_DIR/processor-tests.log" ]]; then
        processor_passed=$(awk '/^Passed:/ { print $2 }' "$ARTIFACT_DIR/processor-tests.log" | tail -n 1)
        processor_failed=$(awk '/^Failed:/ { print $2 }' "$ARTIFACT_DIR/processor-tests.log" | tail -n 1)
        if [[ -n "$processor_passed" && -n "$processor_failed" ]]; then
            processor_total=$((processor_passed + processor_failed))
            if [[ $processor_total -gt 0 ]]; then
                processor_percent=$((processor_passed * 100 / processor_total))
            fi
        fi
    fi

    if [[ -f "$ARTIFACT_DIR/live-classification.log" ]]; then
        local live_summary
        live_summary=$(grep -E "Summary: [0-9]+/[0-9]+ passed" "$ARTIFACT_DIR/live-classification.log" | tail -n 1 || true)
        if [[ -n "$live_summary" ]]; then
            live_passed=$(printf '%s\n' "$live_summary" | sed -E 's/.*Summary: ([0-9]+)\/([0-9]+) passed.*/\1/')
            live_total=$(printf '%s\n' "$live_summary" | sed -E 's/.*Summary: ([0-9]+)\/([0-9]+) passed.*/\2/')
            if [[ -n "$live_passed" && -n "$live_total" && "$live_total" -gt 0 ]]; then
                live_percent=$((live_passed * 100 / live_total))
            fi
        fi
    fi

    if [[ -f "$ARTIFACT_DIR/audio-log-matches.txt" ]]; then
        audio_markers=$(wc -l < "$ARTIFACT_DIR/audio-log-matches.txt" | tr -d ' ')
    fi

    if [[ -f "$ARTIFACT_DIR/latency-samples.tsv" ]]; then
        latency_samples=$(awk 'NR > 1 && ($3 != "") { count += 1 } END { print count + 0 }' "$ARTIFACT_DIR/latency-samples.tsv")
        best_first_text=$(awk 'NR > 1 && ($3 != "") { if (best == "" || $3 < best) best = $3 } END { print best }' "$ARTIFACT_DIR/latency-samples.tsv")
        latest_first_text=$(awk 'NR > 1 && ($3 != "") { latest = $3 } END { print latest }' "$ARTIFACT_DIR/latency-samples.tsv")
        latest_card_start=$(awk 'NR > 1 && ($2 != "") { latest = $2 } END { print latest }' "$ARTIFACT_DIR/latency-samples.tsv")
        latest_complete=$(awk 'NR > 1 && ($4 != "") { latest = $4 } END { print latest }' "$ARTIFACT_DIR/latency-samples.tsv")
        latest_card_to_first=$(awk 'NR > 1 && ($5 != "") { latest = $5 } END { print latest }' "$ARTIFACT_DIR/latency-samples.tsv")
        max_first_text=$(awk 'NR > 1 && ($3 != "") { if (max == "" || $3 > max) max = $3 } END { print max }' "$ARTIFACT_DIR/latency-samples.tsv")
        over_target_count=$(awk 'NR > 1 && ($3 != "" && $3 > 1000) { count += 1 } END { print count + 0 }' "$ARTIFACT_DIR/latency-samples.tsv")
    fi

    {
        echo "# Interview latency and quality score"
        echo
        echo "This score is a progress artifact for latency improvement loops. It is not a substitute for reviewing the diff."
        echo
        echo "## Visible answer latency"
        if [[ "$latency_samples" -gt 0 ]]; then
            echo "- samples: ${latency_samples}"
            echo "- latest_card_start_ms: ${latest_card_start:-unavailable}"
            echo "- latest_first_answer_text_ms: ${latest_first_text:-unavailable}"
            echo "- latest_answer_complete_ms: ${latest_complete:-unavailable}"
            echo "- latest_card_to_first_text_ms: ${latest_card_to_first:-unavailable}"
            echo "- best_first_answer_text_ms: ${best_first_text:-unavailable}"
            echo "- max_first_answer_text_ms: ${max_first_text:-unavailable}"
            if [[ -n "$over_target_count" && "$over_target_count" -eq 0 ]]; then
                echo "- first_text_target: pass"
            else
                echo "- first_text_target: fail_or_unavailable"
                echo "- first_text_over_target_samples: ${over_target_count:-unavailable}"
            fi
            echo "- samples_file: ${ARTIFACT_DIR}/latency-samples.tsv"
        else
            echo "- score: unavailable"
            echo "- reason: no card-to-answer latency samples found in recent app logs"
            echo "- expected logs: processorDidStartStreaming, Chunk received or processorDidReceiveAnswerChunk, Answer complete or processorDidFinishAnswer"
        fi
        echo
        echo "## Deterministic processor checks"
        if [[ -n "$processor_percent" ]]; then
            echo "- score: ${processor_percent}%"
            echo "- passed: ${processor_passed}/${processor_total}"
            echo "- failed: ${processor_failed}"
        else
            echo "- score: unavailable"
            echo "- reason: processor test summary was not found"
        fi
        echo
        echo "## Live classification checks"
        if [[ -n "$live_percent" ]]; then
            echo "- score: ${live_percent}%"
            echo "- passed: ${live_passed}/${live_total}"
        elif [[ "$RUN_LIVE_CLASSIFICATION" == "1" ]]; then
            echo "- score: unavailable"
            echo "- reason: live classification ran but no summary line was found"
        else
            echo "- score: skipped"
            echo "- reason: set IM_RUN_LIVE_CLASSIFICATION=1"
        fi
        echo
        echo "## Audio/log smoke"
        if [[ "$RUN_AUDIO_SMOKE" == "1" ]]; then
            echo "- markers: ${audio_markers}"
            echo "- strict: ${AUDIO_STRICT}"
        else
            echo "- score: skipped"
            echo "- reason: set IM_RUN_AUDIO_SMOKE=1"
        fi
        echo
        echo "## Improvement guidance"
        echo "- Optimize latest_first_answer_text_ms first; target under 1000ms for clear questions."
        echo "- Do not treat card_start_ms alone as success if the card body is still empty."
        echo "- Try model, prompt, token budget, streaming, provisional-answer, and answer-update changes when justified by logs."
        echo "- Preserve question-detection and answer-quality scores while improving latency."
    } > "$report"

    append_summary "## quality-score"
    append_summary ""
    append_summary "log: ${report}"
    append_summary ""
}

append_summary "# InterviewMaster verification"
append_summary ""
append_summary "artifact_dir: ${ARTIFACT_DIR}"
append_summary "root: ${ROOT_DIR}"
append_summary ""

run_step build bash build.sh
run_step processor-tests bash Tests/test.sh

if [[ "$RUN_LIVE_CLASSIFICATION" == "1" ]]; then
    run_step live-classification swift test_classification.swift
else
    append_summary "## live-classification"
    append_summary ""
    append_summary "status: skipped"
    append_summary "reason: set IM_RUN_LIVE_CLASSIFICATION=1 to run Groq-backed classification checks"
    append_summary ""
fi

if [[ "$RUN_AUDIO_SMOKE" == "1" ]]; then
    if [[ ! -f "$AUDIO_FIXTURE" ]]; then
        append_summary "## audio-smoke"
        append_summary ""
        append_summary "status: fail"
        append_summary "reason: audio fixture not found: ${AUDIO_FIXTURE}"
        append_summary ""
        STATUS=1
    else
        if [[ "$START_APP" == "1" ]]; then
            rm -f /tmp/interviewmaster.out
            if [[ "$AUDIO_AUTO_START_INTERVIEW" == "1" ]]; then
                run_step start-app env IM_AUTO_START_INTERVIEW=1 bash start.sh
            else
                run_step start-app bash start.sh
            fi
        fi

        sleep "$AUDIO_WARMUP_SECONDS"
        run_step audio-playback afplay "$AUDIO_FIXTURE"
        sleep "$AUDIO_SETTLE_SECONDS"
        collect_logs

        append_summary "## audio-log-check"
        append_summary ""
        if grep -E "TRANSCRIBE:|CLASSIFY:|ANSWER:|processAudioSegment|processorDidReceiveQuestion" "$ARTIFACT_DIR/recent-app-logs.txt" > "$ARTIFACT_DIR/audio-log-matches.txt"; then
            append_summary "status: pass"
            append_summary "log: ${ARTIFACT_DIR}/audio-log-matches.txt"
        else
            append_summary "status: fail"
            append_summary "reason: no transcription/classification/answer markers found after playback"
            append_summary "log: ${ARTIFACT_DIR}/recent-app-logs.txt"
            if [[ "$AUDIO_STRICT" == "1" ]]; then
                STATUS=1
            fi
        fi
        append_summary ""
    fi
else
    collect_logs
    append_summary "## audio-smoke"
    append_summary ""
    append_summary "status: skipped"
    append_summary "reason: set IM_RUN_AUDIO_SMOKE=1 to play an audio fixture through system output"
    append_summary ""
fi

extract_latency_samples
write_quality_score

append_summary "## final-status"
append_summary ""
if [[ $STATUS -eq 0 ]]; then
    append_summary "pass"
else
    append_summary "fail"
fi

printf 'Verification artifacts: %s\n' "$ARTIFACT_DIR"
printf 'Summary: %s\n' "$SUMMARY"

exit $STATUS
