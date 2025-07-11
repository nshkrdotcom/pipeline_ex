#!/bin/bash

# Research Paper Improvement Pipeline Loop
# Hardcoded to use research_paper_improvement_gemini_pro_delayed.yaml
# Chains iterations by feeding outputs back as inputs

PIPELINE_FILE="research_paper_improvement_gemini_pro_delayed.yaml"

# Check if the pipeline file exists
if [ ! -f "$PIPELINE_FILE" ]; then
    echo "Error: Pipeline file '$PIPELINE_FILE' not found!"
    exit 1
fi

echo "Starting research paper improvement pipeline loop"
echo "Pipeline: $PIPELINE_FILE"
echo "Press Ctrl+C to stop"
echo ""

counter=1
while true; do
    timestamp=$(date -u +"%Y%m%d%H%M")
    echo "=== Research Paper Improvement Run #$counter $(date -u) ==="
    
    # Create temporary YAML with unique timestamp
    cp "$PIPELINE_FILE" "${PIPELINE_FILE}.tmp"
    
    # Replace {{timestamp}} markers in output_to_file fields with current timestamp
    sed -i "s|{{timestamp}}|$timestamp|g" "${PIPELINE_FILE}.tmp"
    
    # Find the most recent output file to use as input for next iteration
    if [ $counter -gt 1 ]; then
        # Look for latest file in outputs directory (where files are actually saved)
        latest_file=$(ls -t ./outputs/202*_improved_chiral_narrative_synthesis.md 2>/dev/null | head -1)
        if [ -n "$latest_file" ]; then
            echo "🔄 Using previous output as input: $latest_file"
            # Update the file path in the YAML to point to the latest output
            sed -i 's|path: "\.\./research_papers/tex/ResearchProposal-ChiralNarrativeSynthesis_3\.tex"|path: "'"$latest_file"'"|g' "${PIPELINE_FILE}.tmp"
            sed -i 's|path: \.\./research_papers/tex/ResearchProposal-ChiralNarrativeSynthesis_3\.tex|path: "'"$latest_file"'"|g' "${PIPELINE_FILE}.tmp"
        else
            echo "⚠️  No previous output found, using original research proposal"
        fi
    else
        echo "🚀 First run - using original research proposal"
    fi
    
    # Run the pipeline
    echo "🧠 Executing Gemini research improvement..."
    start_time=$(date +%s)
    
    if timeout 3600 mix pipeline.run.live "${PIPELINE_FILE}.tmp"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "✅ Pipeline completed successfully in ${duration}s"
        
        # Check if new output file was created
        echo "🔍 Checking for new output files..."
        latest_after=$(ls -t ./outputs/202*_improved_chiral_narrative_synthesis.md 2>/dev/null | head -1)
        echo "📁 Latest file found: $latest_after"
        echo "📁 Previous file was: $latest_file"
        
        if [ "$latest_after" != "$latest_file" ]; then
            echo "📄 New improved paper created: $latest_after"
            
            # Show file size for progress tracking
            if [ -f "$latest_after" ]; then
                echo "📊 Calculating file size..."
                size=$(wc -l < "$latest_after" 2>/dev/null || echo "unknown")
                echo "📊 Paper length: $size lines"
            fi
        else
            echo "⚠️  WARNING: No new output file detected!"
        fi
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "❌ Pipeline failed or timed out after ${duration}s"
        
        # Show current outputs for debugging
        echo "📁 Current outputs:"
        ls -lt ./outputs/202*_improved_chiral_narrative_synthesis.md 2>/dev/null | head -3
    fi
    
    # Clean up temp file
    rm "${PIPELINE_FILE}.tmp"
    
    echo "=== Completed Research Paper Improvement Run #$counter ==="
    echo "⏱️  Pausing for 5 seconds before next iteration..."
    echo "   (Press Ctrl+C now to stop the loop)"
    sleep 5
    echo ""
    ((counter++))
done