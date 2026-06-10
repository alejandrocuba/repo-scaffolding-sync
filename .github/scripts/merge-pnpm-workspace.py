#!/usr/bin/env python3
import sys
import os
import re

def group_by_top_level_keys(content):
    lines = content.splitlines()
    blocks = {}
    pending_comments = []
    current_key = None
    current_lines = []
    
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            pending_comments.append(line)
            continue
            
        indent = len(line) - len(line.lstrip())
        if indent == 0 and ':' in line and not line.lstrip().startswith('-'):
            # Save previous block
            if current_key is not None:
                blocks[current_key] = current_lines
            
            # Start new block with pending comments
            current_key = line.split(':', 1)[0].strip().strip("'\"")
            current_lines = pending_comments + [line]
            pending_comments = []
        else:
            # Indented content or list items
            current_lines.extend(pending_comments)
            pending_comments = []
            current_lines.append(line)
            
    if current_key is not None:
        current_lines.extend(pending_comments)
        blocks[current_key] = current_lines
    elif pending_comments:
        if '' not in blocks:
            blocks[''] = []
        blocks[''].extend(pending_comments)
        
    return blocks

def parse_allow_builds(block_lines):
    allowed = {}
    for line in block_lines:
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or ':' not in stripped:
            continue
        parts = stripped.split(':', 1)
        k = parts[0].strip().strip("'\"")
        v = parts[1].strip()
        if k == 'allowBuilds':
            continue
        allowed[k] = v.lower() == 'true'
    return allowed

def get_scalar_value(block_lines, key):
    for line in block_lines:
        stripped = line.strip()
        if stripped.startswith(key + ':'):
            return stripped.split(':', 1)[1].strip()
    return None

def set_scalar_value(block_lines, key, new_val):
    new_lines = []
    for line in block_lines:
        stripped = line.strip()
        if stripped.startswith(key + ':'):
            indent = len(line) - len(line.lstrip())
            new_lines.append(' ' * indent + f"{key}: {new_val}")
        else:
            new_lines.append(line)
    return new_lines

def main():
    if len(sys.argv) < 4:
        print("Usage: merge-pnpm-workspace.py <template_path> <consumer_path> <output_path>")
        sys.exit(1)
        
    template_path = sys.argv[1]
    consumer_path = sys.argv[2]
    output_path = sys.argv[3]
    
    if not os.path.exists(template_path):
        print(f"Error: Template path {template_path} does not exist.")
        sys.exit(1)
        
    # Read files
    with open(template_path, 'r') as f:
        template_content = f.read()
        
    consumer_content = ""
    if os.path.exists(consumer_path):
        with open(consumer_path, 'r') as f:
            consumer_content = f.read()
            
    # If consumer file is empty/non-existent, just copy template
    if not consumer_content.strip():
        with open(output_path, 'w') as f:
            f.write(template_content)
        print("Consumer file is empty or missing, copied template directly.")
        sys.exit(0)
        
    # Group by top-level keys
    template_blocks = group_by_top_level_keys(template_content)
    consumer_blocks = group_by_top_level_keys(consumer_content)
    
    merged_blocks = {}
    
    # 1. Packages block
    # Prefer consumer's packages block if it exists
    if 'packages' in consumer_blocks:
        merged_blocks['packages'] = consumer_blocks['packages']
    else:
        merged_blocks['packages'] = template_blocks.get('packages', [])
        
    # 2. AllowBuilds block
    if 'allowBuilds' in template_blocks:
        # Merge allowBuilds
        t_allow = parse_allow_builds(template_blocks['allowBuilds'])
        c_allow = parse_allow_builds(consumer_blocks.get('allowBuilds', []))
        
        # Merge dictionaries (consumer settings override template)
        merged_allow = t_allow.copy()
        for k, v in c_allow.items():
            merged_allow[k] = v
            
        # Re-generate allowBuilds block based on template structure
        merged_blocks['allowBuilds'] = []
        for line in template_blocks['allowBuilds']:
            stripped = line.strip()
            merged_blocks['allowBuilds'].append(line)
            if stripped == 'allowBuilds:':
                break
        for pkg, allowed in sorted(merged_allow.items()):
            val_str = "true" if allowed else "false"
            pkg_key = f'"{pkg}"' if pkg.startswith('@') else pkg
            merged_blocks['allowBuilds'].append(f"  {pkg_key}: {val_str}")
            
    # 3. Security policies
    security_keys = ['blockExoticSubdeps', 'trustPolicy', 'minimumReleaseAge']
    for key in security_keys:
        if key in template_blocks:
            val = get_scalar_value(consumer_blocks.get(key, []), key)
            if val is not None:
                # Use consumer override
                merged_blocks[key] = set_scalar_value(template_blocks[key], key, val)
            else:
                # Use template default
                merged_blocks[key] = template_blocks[key]
                
    # 4. Any other custom consumer blocks (like catalog, catalogs, etc.)
    known_keys = {'packages', 'allowBuilds', 'blockExoticSubdeps', 'trustPolicy', 'minimumReleaseAge'}
    custom_consumer_keys = [k for k in consumer_blocks if k not in known_keys and k != '']
    
    # Write output
    output_lines = []
    
    # Write leading comments from template if any
    if '' in template_blocks:
        output_lines.extend(template_blocks[''])
        
    # Write packages
    if 'packages' in merged_blocks:
        output_lines.extend(merged_blocks['packages'])
        output_lines.append("")
        
    # Write allowBuilds
    if 'allowBuilds' in merged_blocks:
        output_lines.extend(merged_blocks['allowBuilds'])
        output_lines.append("")
        
    # Write security parameters in original order (from template keys)
    for key in security_keys:
        if key in merged_blocks:
            output_lines.extend(merged_blocks[key])
            output_lines.append("")
            
    # Write custom consumer blocks
    if custom_consumer_keys:
        output_lines.append("# ==============================================================================")
        output_lines.append("# Project-Specific Custom Workspace Settings")
        output_lines.append("# ==============================================================================")
        for key in custom_consumer_keys:
            output_lines.extend(consumer_blocks[key])
            output_lines.append("")
            
    # Clean up multiple trailing newlines
    result_content = "\n".join(output_lines)
    result_content = re.sub(r'\n{3,}', '\n\n', result_content)
    
    with open(output_path, 'w') as f:
        f.write(result_content.rstrip() + "\n")
        
    print(f"Successfully merged pnpm-workspace.yaml into {output_path}")

if __name__ == '__main__':
    main()
