#!/usr/bin/env python3
"""
Process Claude Code hooks from YAML files and generate JSON configuration.
This script is called during the build process to merge hooks into settings.json.
"""

import json
import os
import sys
import re
from pathlib import Path


def parse_yaml_simple(file_path):
    """Simple YAML parser for hook files - handles our specific format."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Extract fields using regex
    hook_data = {
        'id': '',
        'name': '',
        'description': '',
        'events': [],
        'matcher': '',
        'command': '',
        'script': ''
    }
    
    # Extract simple fields
    id_match = re.search(r'^id:\s*(.+)$', content, re.MULTILINE)
    if id_match:
        hook_data['id'] = id_match.group(1).strip()
    
    name_match = re.search(r'^name:\s*(.+)$', content, re.MULTILINE)
    if name_match:
        hook_data['name'] = name_match.group(1).strip()
    
    description_match = re.search(r'^description:\s*(.+)$', content, re.MULTILINE)
    if description_match:
        hook_data['description'] = description_match.group(1).strip()
    
    # Extract events list
    events_section = re.search(r'^events:\s*\n((?:\s+-\s+.+\n?)+)', content, re.MULTILINE)
    if events_section:
        events_text = events_section.group(1)
        hook_data['events'] = re.findall(r'^\s+-\s+(.+)$', events_text, re.MULTILINE)
    
    # Extract configuration section
    config_section = re.search(r'^configuration:\s*\n((?:\s+.+\n?)+)', content, re.MULTILINE)
    if config_section:
        config_text = config_section.group(1)
        
        # Extract matcher
        matcher_match = re.search(r'^\s+matcher:\s*"([^"]*)"', config_text, re.MULTILINE)
        if matcher_match:
            hook_data['matcher'] = matcher_match.group(1)
        
        # Extract command
        command_match = re.search(r'^\s+command:\s*"([^"]+)"', config_text, re.MULTILINE)
        if command_match:
            hook_data['command'] = command_match.group(1)
    
    # Extract script block
    script_match = re.search(r'^script:\s*\|\s*\n((?:\s{2}.+\n?)+)', content, re.MULTILINE)
    if script_match:
        script_text = script_match.group(1)
        # Remove 2-space indentation from each line
        script_lines = []
        for line in script_text.split('\n'):
            if line.startswith('  '):
                script_lines.append(line[2:])
            elif line.strip() == '':
                script_lines.append('')
        hook_data['script'] = '\n'.join(script_lines).strip()
    
    return hook_data


def generate_hooks_config(hooks_dir, scripts_dir):
    """Generate hooks configuration from YAML files."""
    hooks_config = {}
    
    # Process each YAML file
    for yaml_file in Path(hooks_dir).glob('*.yaml'):
        print(f"Processing hook: {yaml_file.name}", file=sys.stderr)
        
        try:
            hook_data = parse_yaml_simple(yaml_file)
            
            # Create script file if script content exists
            if hook_data['script']:
                script_filename = f"{hook_data['id']}.sh"
                script_path = Path(scripts_dir) / script_filename
                
                # Write script with proper shebang
                with open(script_path, 'w') as f:
                    # Ensure script starts with shebang if not present
                    if not hook_data['script'].startswith('#!'):
                        f.write('#!/bin/bash\n')
                    f.write(hook_data['script'])
                
                # Make executable
                os.chmod(script_path, 0o755)
                print(f"  Created script: {script_filename}", file=sys.stderr)
            
            # Add to hooks configuration for each event
            for event in hook_data['events']:
                if event not in hooks_config:
                    hooks_config[event] = []
                
                # Check if we already have a matcher entry for this event
                matcher_found = False
                for entry in hooks_config[event]:
                    if entry['matcher'] == hook_data['matcher']:
                        # Add to existing matcher's hooks
                        entry['hooks'].append({
                            'type': 'command',
                            'command': hook_data['command']
                        })
                        matcher_found = True
                        break
                
                if not matcher_found:
                    # Create new matcher entry
                    hooks_config[event].append({
                        'matcher': hook_data['matcher'],
                        'hooks': [{
                            'type': 'command',
                            'command': hook_data['command']
                        }]
                    })
                
                print(f"  Added to event: {event}", file=sys.stderr)
        
        except Exception as e:
            print(f"Error processing {yaml_file}: {e}", file=sys.stderr)
            continue
    
    return {'hooks': hooks_config}


def merge_with_settings(hooks_config, settings_template_path, output_path):
    """Merge hooks configuration with existing settings template."""
    # Load existing settings if they exist
    if os.path.exists(settings_template_path):
        with open(settings_template_path, 'r') as f:
            settings = json.load(f)
    else:
        settings = {}
    
    # Merge hooks configuration
    if 'hooks' in settings:
        # Merge with existing hooks
        for event, matchers in hooks_config['hooks'].items():
            if event in settings['hooks']:
                # Merge matchers
                existing_matchers = {m['matcher']: m for m in settings['hooks'][event]}
                for new_matcher in matchers:
                    if new_matcher['matcher'] in existing_matchers:
                        # Merge hooks for this matcher
                        existing_matchers[new_matcher['matcher']]['hooks'].extend(new_matcher['hooks'])
                    else:
                        settings['hooks'][event].append(new_matcher)
            else:
                settings['hooks'][event] = matchers
    else:
        # No existing hooks, just add ours
        settings.update(hooks_config)
    
    # Write merged settings
    with open(output_path, 'w') as f:
        json.dump(settings, f, indent=2)
    
    return settings


def main():
    if len(sys.argv) != 4:
        print("Usage: process-hooks.py <hooks_dir> <scripts_output_dir> <settings_output_path>", file=sys.stderr)
        sys.exit(1)
    
    hooks_dir = sys.argv[1]
    scripts_dir = sys.argv[2]
    settings_output = sys.argv[3]
    
    # Ensure scripts directory exists
    Path(scripts_dir).mkdir(parents=True, exist_ok=True)
    
    # Generate hooks configuration
    hooks_config = generate_hooks_config(hooks_dir, scripts_dir)
    
    # For now, just write the hooks configuration
    # In a full implementation, this would merge with the existing settings template
    print(json.dumps(hooks_config, indent=2))
    
    # Also save to a separate file for debugging
    hooks_only_path = Path(scripts_dir).parent / 'claude-hooks-config.json'
    with open(hooks_only_path, 'w') as f:
        json.dump(hooks_config, f, indent=2)
    
    print(f"\nHooks configuration saved to: {hooks_only_path}", file=sys.stderr)


if __name__ == '__main__':
    main()
