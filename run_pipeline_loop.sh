#!/bin/bash

# Check if pipeline YAML file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <pipeline.yaml> [starting_file]"
    echo "Example: $0 engineering_innovation_pipeline.yaml"
    echo "Example: $0 engineering_innovation_pipeline.yaml ./workspace/large_file.md"
    exit 1
fi

PIPELINE_FILE="$1"
STARTING_FILE="$2"

# Check if the pipeline file exists
if [ ! -f "$PIPELINE_FILE" ]; then
    echo "Error: Pipeline file '$PIPELINE_FILE' not found!"
    exit 1
fi

echo "Starting pipeline loop for: $PIPELINE_FILE"
echo "Press Ctrl+C to stop"
echo ""

counter=1
while true; do
    timestamp=$(date -u +"%Y%m%d%H%M")
    echo "=== Pipeline Run #$counter $(date -u) ==="
    
    # Create temporary YAML with unique timestamp
    cp "$PIPELINE_FILE" "${PIPELINE_FILE}.tmp"
    sed -i "s|TIMESTAMP_PLACEHOLDER|$timestamp|g" "${PIPELINE_FILE}.tmp"
    
    # Replace {{timestamp}} markers in output_to_file fields with current timestamp
    sed -i "s|{{timestamp}}|$timestamp|g" "${PIPELINE_FILE}.tmp"
    
    # Also replace TIMESTAMP_PLACEHOLDER in log paths
    sed -i "s|TIMESTAMP_PLACEHOLDER|$timestamp|g" "${PIPELINE_FILE}.tmp"
    
    # Find the most recent output file to use as input for next iteration
    if [ $counter -gt 1 ]; then
        latest_file=$(ls -t ./workspace/202*.md 2>/dev/null | head -1)
        if [ -n "$latest_file" ]; then
            echo "Using previous output as input: $latest_file"
            # Update ALL file paths in the YAML to point to the latest file
            # This replaces any path that references the research proposal file
            sed -i 's|path: "\.\./research_papers/tex/ResearchProposal-ChiralNarrativeSynthesis_3\.tex"|path: "'"$latest_file"'"|g' "${PIPELINE_FILE}.tmp"
            sed -i 's|path: \.\./research_papers/tex/ResearchProposal-ChiralNarrativeSynthesis_3\.tex|path: "'"$latest_file"'"|g' "${PIPELINE_FILE}.tmp"
        fi
    elif [ -n "$STARTING_FILE" ] && [ -f "$STARTING_FILE" ]; then
        echo "Using provided starting file: $STARTING_FILE"
        # Replace the original file paths with the starting file for first iteration
        sed -i 's|path: "\.\./research_papers/tex/ResearchProposal-ChiralNarrativeSynthesis_3\.tex"|path: "'"$STARTING_FILE"'"|g' "${PIPELINE_FILE}.tmp"
        sed -i 's|path: \.\./research_papers/tex/ResearchProposal-ChiralNarrativeSynthesis_3\.tex|path: "'"$STARTING_FILE"'"|g' "${PIPELINE_FILE}.tmp"
    fi
    
    # Run pipeline with timeout detection and enhanced logging
    echo "🚀 Starting pipeline execution..."
    start_time=$(date +%s)
    
    if timeout 3600 mix pipeline.run.live "${PIPELINE_FILE}.tmp"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "✅ Pipeline completed successfully in ${duration}s"
        
        # Check if expected output file was created
        latest_after=$(ls -t ./workspace/202*.md 2>/dev/null | head -1)
        if [ "$latest_after" != "$latest_file" ]; then
            echo "📄 New output file created: $latest_after"
        else
            echo "⚠️  WARNING: No new output file detected!"
        fi
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "❌ Pipeline failed or timed out after ${duration}s"
        
        # Check for partial logs
        echo "🔍 Checking for conversation logs..."
        ls -la ./logs/*$timestamp* 2>/dev/null || echo "No conversation logs found"
        
        # Show workspace files for debugging
        echo "📁 Current workspace contents:"
        ls -lt ./workspace/202*.md 2>/dev/null | head -5
    fi
    
    # Clean up temp file
    rm "${PIPELINE_FILE}.tmp"
    
    echo "=== Completed Run #$counter, waiting 5 seconds... ==="
    sleep 5
    ((counter++))
done