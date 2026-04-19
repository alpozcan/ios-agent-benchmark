#!/usr/bin/env python3
"""
Gather code metrics from two generated codebases for OQM scoring.

Usage:
    python3 gather-metrics.py <dir-a> <dir-b> <source-dir-name> [--platform ios]

Outputs JSON to stdout with all raw counts needed by oqm-scorer.py.

Example:
    python3 gather-metrics.py ./runs/runA ./runs/runB Atlas \
        --platform ios --names runA runB > results/raw-metrics.json
"""

import argparse
import json
import os
import subprocess
import re


def count_pattern(path, pattern, exclude_comments=True):
    """Count regex pattern matches in Swift files."""
    cmd = f'grep -rn "{pattern}" {path} --include="*.swift" 2>/dev/null'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    lines = result.stdout.strip().split('\n') if result.stdout.strip() else []
    if exclude_comments:
        lines = [l for l in lines if '//' not in l.split(':')[0] if l]
    return len([l for l in lines if l])


def file_lines(path, exclude=None):
    """Count total lines in Swift files."""
    exclude = exclude or []
    total = 0
    for root, dirs, files in os.walk(path):
        for f in files:
            if f.endswith('.swift') and f not in exclude:
                with open(os.path.join(root, f)) as fh:
                    total += sum(1 for _ in fh)
    return total


def file_count(path, exclude=None):
    """Count Swift files."""
    exclude = exclude or []
    count = 0
    for root, dirs, files in os.walk(path):
        for f in files:
            if f.endswith('.swift') and f not in exclude:
                count += 1
    return count


def god_classes(path, threshold=300, exclude=None):
    """Find files exceeding line threshold."""
    exclude = exclude or []
    result = []
    for root, dirs, files in os.walk(path):
        for f in files:
            if f.endswith('.swift') and f not in exclude:
                fp = os.path.join(root, f)
                with open(fp) as fh:
                    lines = sum(1 for _ in fh)
                if lines > threshold:
                    result.append((os.path.relpath(fp, path), lines))
    return result


def gather_model_metrics(code_dir, source_dir, platform="ios"):
    """Gather all metrics for one model's output."""
    src = os.path.join(code_dir, source_dir)
    exclude = []  # Add any scaffold files to exclude
    all_code = ""
    for root, dirs, files in os.walk(src):
        for f in files:
            if f.endswith('.swift') and f not in exclude:
                with open(os.path.join(root, f)) as fh:
                    all_code += fh.read() + "\n"

    metrics = {
        # Volume
        "files": file_count(src, exclude),
        "lines": file_lines(src, exclude),
        "god_classes": len(god_classes(src, 300, exclude)),

        # DRY
        "dry_uuid_inits": len(re.findall(r'id: UUID = UUID\(\)', all_code)),
        "dry_empty_catch": len(re.findall(r'catch\s*\{\s*\}', all_code)),

        # SOLID
        "solid_types": len(re.findall(r'^(struct|class|enum|actor)\s+', all_code, re.MULTILINE)),
        "solid_protocols": len(re.findall(r'^protocol\s+', all_code, re.MULTILINE)),
        "solid_protocol_conformances": len(re.findall(r':\s*\w+Protocol|\w+Delegate', all_code)),
        "solid_protocol_extensions": len(re.findall(r'extension\s+\w+Protocol|\w+Delegate', all_code)),
        "solid_concrete_in_ui": all_code.count('SwiftData') - all_code[:all_code.find('UI/')].count('SwiftData') if 'UI/' in all_code else 0,

        # Quality flags
        "force_unwrap": len(re.findall(r'\w+!\.', all_code)),
        "try_bang": all_code.count('try!'),
        "as_bang": all_code.count(' as!'),
        "fatalError": all_code.count('fatalError'),
        "print_debug": len(re.findall(r'^[^/]*print\(', all_code, re.MULTILINE)),

        # Robustness
        "guard_stmts": len(re.findall(r'^\s*guard\s+', all_code, re.MULTILINE)),
        "nil_coalescing": len(re.findall(r'\?\?', all_code)),
        "do_catch": all_code.count('catch'),
        "throw_throws": len(re.findall(r'\bthrow\b|\bthrows\b', all_code)),
        "result_type": all_code.count('Result<'),
        "doc_comments": len(re.findall(r'/// ', all_code)),

        # Concurrency
        "sendable": all_code.count(': Sendable'),
        "main_actor": all_code.count('@MainActor'),
        "nonisolated": all_code.count('nonisolated'),
        "async_await": all_code.count('await '),
        "unchecked_sendable": all_code.count('@unchecked Sendable'),
        "actor_usage": len(re.findall(r'^actor\s+', all_code, re.MULTILINE)),

        # Platform-specific (iOS)
        "ios_observable": all_code.count('@Observable'),
        "ios_state": all_code.count('@State'),
        "ios_binding": all_code.count('@Binding'),
        "ios_query": all_code.count('@Query'),
        "ios_predicate": all_code.count('#Predicate'),
        "ios_model": all_code.count('@Model'),
        "ios_relationship": all_code.count('@Relationship'),
        "ios_transient": all_code.count('@Transient'),
        "ios_viewBuilder": all_code.count('@ViewBuilder'),
        "ios_onChange": all_code.count('.onChange'),
        "ios_withAnimation": all_code.count('withAnimation'),
        "ios_accessibility": len(re.findall(r'accessibilityLabel|accessibilityValue|accessibilityHint', all_code)),
        "ios_localization": len(re.findall(r'String\(localized|LocalizedStringKey', all_code)),
        "ios_weak_self": all_code.count('[weak self]'),

        # Security
        "sec_input_validation": len(re.findall(r'isEmpty|trimmingCharacters|whitespaces', all_code)),
        "sec_sanitization": len(re.findall(r'sanitize|escape|validate|encoded', all_code)),
        "sec_weak_var": len(re.findall(r'\bweak\b|\bunowned\b', all_code)),

        # Architecture
        "generics": len(re.findall(r'<.*:.*>', all_code)),
        "typealias": all_code.count('typealias'),
        "enums": len(re.findall(r'^enum\s+', all_code, re.MULTILINE)),
        "custom_errors": len(re.findall(r'Error|: Error', all_code)),

        # Memory
        "closures_with_self": len(re.findall(r'\{[^}]*self\.', all_code)),
        "closures_weak_self": all_code.count('[weak self]'),
    }
    return metrics


def main():
    parser = argparse.ArgumentParser(description="Gather metrics from two codebases")
    parser.add_argument("dir_a", help="First model's project directory")
    parser.add_argument("dir_b", help="Second model's project directory")
    parser.add_argument("source_dir", help="Source directory name (e.g., 'Nexus', 'Sources')")
    parser.add_argument("--platform", default="ios", help="Platform: ios, android, backend")
    parser.add_argument("--names", nargs=2, default=["model-a", "model-b"], help="Model names for output")
    args = parser.parse_args()

    result = {
        args.names[0]: gather_model_metrics(args.dir_a, args.source_dir, args.platform),
        args.names[1]: gather_model_metrics(args.dir_b, args.source_dir, args.platform),
    }

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
