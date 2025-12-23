---
name: Shell Remote Test
description: Copy shell scripts to remote test machine 10.16.203.61 and execute tests. Use this skill when user wants to test scripts on remote machine.
allowed-tools: Bash, Read
---

# Shell Remote Test Skill

## When to Use This Skill

Activate this skill when the user requests:
- "test script on remote machine"
- "copy script to 10.16.203.61"
- "run script on test server"
- "remote test shell script"

## Execution Steps

### 1. Parse Arguments
- Script path: First argument from $ARGUMENTS (required)
- Remote user: Second argument (optional, default: root)
- Remote path: Third argument (optional, default: /tmp)

### 2. Validate Script File
- Check if script file exists
- Check if script has execute permission

### 3. Copy Script to Remote Machine
Use the helper script to copy and execute:
```bash
bash /Users/pengzz/go/src/github.com/mulei1288/scripts/.claude/skills/shell-remote-test/remote-test.sh "$ARGUMENTS"
```

### 4. Execute on Remote Machine
The helper script will:
- Test SSH connection
- Copy script using scp
- Set execute permission
- Run the script remotely
- Capture output and exit code
- Clean up remote files (optional)

### 5. Report Results
Display:
- Script output
- Exit code
- Execution time
- Success/failure status

## Usage Examples

### Basic Usage
```
/shell-remote-test /path/to/script.sh
```

### Specify Remote User
```
/shell-remote-test /path/to/script.sh root
```

### With Script Arguments
```
/shell-remote-test /path/to/script.sh root /tmp -- --verbose
```

## Output Format

### Test Start
```
[INFO] Starting remote test
Script: <local-path>
Remote: 10.16.203.61
User: <username>
Path: <remote-path>
```

### Copy Phase
```
[INFO] Copying script to remote machine...
[SUCCESS] Copy successful
```

### Execution Phase
```
[INFO] Executing remote script...
Command: bash <remote-path>/<script-name> <args>

--- Script Output ---
<stdout and stderr>
--- End Output ---
```

### Test Results
```
[INFO] Test Results
Exit Code: <code>
Duration: <seconds>s
Status: <SUCCESS/FAILED>
```

## Error Handling

Common errors and solutions:

1. **Script file not found**
   - Check file path
   - Check file permissions

2. **SSH connection failed**
   - Check network connectivity
   - Verify SSH key configuration
   - Confirm remote host IP

3. **SCP copy failed**
   - Check remote path exists
   - Check user permissions
   - Check disk space

4. **Script execution failed**
   - Review script output for errors
   - Check script dependencies
   - Verify remote environment

## Prerequisites

1. SSH passwordless login configured to 10.16.203.61
2. Remote machine accessible
3. Remote path exists with write permission

## Advanced Features

### Run shellcheck before test
```
/shell-remote-test /path/to/script.sh --check
```

### Keep remote file after test
```
/shell-remote-test /path/to/script.sh --no-cleanup
```

### Specify custom remote path
```
/shell-remote-test /path/to/script.sh root /opt/test
```
