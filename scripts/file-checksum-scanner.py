#!/usr/bin/env python3
"""
File checksum scanner for verifying deployments.
Outputs tab-delimited data suitable for spreadsheet import.
"""

import os
import sys
import hashlib
import argparse
from pathlib import Path


def calculate_checksum(filepath, algorithm='sha256'):
    """Calculate the checksum of a file using the specified algorithm."""
    hash_func = hashlib.new(algorithm)
    
    try:
        with open(filepath, 'rb') as f:
            # Read file in chunks to handle large files efficiently
            for chunk in iter(lambda: f.read(4096), b''):
                hash_func.update(chunk)
        return hash_func.hexdigest()
    except Exception as e:
        return f"ERROR: {str(e)}"


def get_file_info(filepath, base_dir):
    """Get file information including name, checksum, size, and directory."""
    try:
        file_path = Path(filepath)
        file_name = file_path.name
        file_size = file_path.stat().st_size
        checksum = calculate_checksum(filepath)
        
        # Get relative directory path
        rel_dir = file_path.parent.relative_to(base_dir)
        directory = str(rel_dir) if str(rel_dir) != '.' else '.'
        
        return {
            'name': file_name,
            'checksum': checksum,
            'size': file_size,
            'directory': directory
        }
    except Exception as e:
        return {
            'name': Path(filepath).name,
            'checksum': f"ERROR: {str(e)}",
            'size': 0,
            'directory': 'ERROR'
        }


def scan_directory(directory, recursive=False):
    """Scan directory for files and return their information."""
    base_dir = Path(directory).resolve()
    files_info = []
    
    if recursive:
        # Recursively walk through all subdirectories
        for root, dirs, files in os.walk(base_dir):
            for file in files:
                filepath = os.path.join(root, file)
                files_info.append(get_file_info(filepath, base_dir))
    else:
        # Only scan files in the current directory
        for item in base_dir.iterdir():
            if item.is_file():
                files_info.append(get_file_info(item, base_dir))
    
    # Sort by filename alphabetically
    files_info.sort(key=lambda x: x['name'].lower())
    
    return files_info


def print_results(files_info):
    """Print results in tab-delimited format."""
    # Print header
    print("File Name\tChecksum\tSize (bytes)\tDirectory")
    
    # Print file information
    for file_info in files_info:
        print(f"{file_info['name']}\t{file_info['checksum']}\t{file_info['size']}\t{file_info['directory']}")


def main():
    parser = argparse.ArgumentParser(
        description='Generate checksums and file information for deployment verification'
    )
    parser.add_argument(
        'directory',
        help='Directory to scan'
    )
    parser.add_argument(
        '-r', '--recursive',
        action='store_true',
        help='Recursively scan subdirectories'
    )
    
    args = parser.parse_args()
    
    # Validate directory exists
    if not os.path.exists(args.directory):
        print(f"Error: Directory '{args.directory}' does not exist", file=sys.stderr)
        sys.exit(1)
    
    if not os.path.isdir(args.directory):
        print(f"Error: '{args.directory}' is not a directory", file=sys.stderr)
        sys.exit(1)
    
    # Scan directory and get file information
    files_info = scan_directory(args.directory, args.recursive)
    
    if not files_info:
        print("No files found in the specified directory", file=sys.stderr)
        sys.exit(0)
    
    # Print results
    print_results(files_info)


if __name__ == '__main__':
    main()
