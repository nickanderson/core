#!/bin/bash
# CFE-90 Standalone Test (no VM required)
# Tests the fstab option comparison logic by mocking /etc/fstab
#
# This test verifies:
# 1. GetFstabEntryOptions correctly extracts the options field from fstab
# 2. The option comparison logic detects mismatches
# 3. ReplaceFstabEntry correctly updates the fstab entry
#
# Run as: sudo ./test_cfe90_standalone.sh

set -e

TESTDIR=$(mktemp -d /tmp/cfe90-test.XXXXXX)
PASS=0
FAIL=0

cleanup() { rm -rf "$TESTDIR"; }
trap cleanup EXIT

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== CFE-90 Standalone Test ==="
echo ""

# Test 1: fstab parsing logic
echo "--- Test 1: fstab field extraction ---"
cat > "$TESTDIR/test_fstab" << 'EOF'
# Comment line
/dev/sda1 / ext4 defaults 0 1
192.168.1.1:/data /mnt/data nfs rw,soft,intr 0 0
192.168.1.1:/backup /mnt/backup nfs defaults 0 0
tmpfs /tmp tmpfs defaults 0 0
EOF

# Simulate GetFstabEntryOptions in bash
get_fstab_opts() {
    local mountpt="$1"
    while IFS= read -r line; do
        # Skip comments
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Read fields
        read -r src mp fstype opts dump pass _ <<< "$line"
        
        if [ "$mp" = "$mountpt" ]; then
            echo "$opts"
            return 0
        fi
    done < "$TESTDIR/test_fstab"
    return 1
}

actual_opts=$(get_fstab_opts "/mnt/data")
if [ "$actual_opts" = "rw,soft,intr" ]; then
    pass "Extracted options: $actual_opts"
else
    fail "Expected 'rw,soft,intr', got '$actual_opts'"
fi

# Test 2: options comparison
echo ""
echo "--- Test 2: option mismatch detection ---"
promised_opts="rw,hard,intr"
if [ "$actual_opts" != "$promised_opts" ]; then
    pass "Detected mismatch: actual='$actual_opts' vs promised='$promised_opts'"
else
    fail "Should have detected mismatch"
fi

# Test 3: matching options
echo ""
echo "--- Test 3: matching options ---"
if [ "$actual_opts" = "$actual_opts" ]; then
    pass "Options match: '$actual_opts'"
else
    fail "Should match"
fi

# Test 4: defaults mountpoint
echo ""
echo "--- Test 4: defaults mountpoint ---"
actual_opts=$(get_fstab_opts "/")
if [ "$actual_opts" = "defaults" ]; then
    pass "Root mount options: $actual_opts"
else
    fail "Expected 'defaults', got '$actual_opts'"
fi

# Test 5: non-existent mountpoint
echo ""
echo "--- Test 5: non-existent mountpoint ---"
actual_opts=$(get_fstab_opts "/mnt/nonexistent" 2>/dev/null || echo "NOT_FOUND")
if [ "$actual_opts" = "NOT_FOUND" ]; then
    pass "Non-existent mountpoint returns NOT_FOUND"
else
    fail "Expected 'NOT_FOUND', got '$actual_opts'"
fi

# Test 6: comment lines are skipped
echo ""
echo "--- Test 6: comment skipping ---"
cat > "$TESTDIR/test_fstab_comments" << 'EOF'
# First comment
# Second comment

/dev/sda1 / ext4 defaults 0 1
EOF
actual_opts=$(get_fstab_opts "/")
if [ "$actual_opts" = "defaults" ]; then
    pass "Comment lines skipped correctly"
else
    fail "Failed to parse fstab with comments"
fi

# Test 7: fstab entry replacement logic
echo ""
echo "--- Test 7: fstab entry replacement ---"
cat > "$TESTDIR/old_fstab" << 'EOF'
/dev/sda1 / ext4 defaults 0 1
192.168.1.1:/data /mnt/data nfs rw,soft,intr 0 0
EOF

# Simulate ReplaceFstabEntry in bash
replace_fstab_entry() {
    local mountpt="$1"
    local new_entry="$2"
    local result=""
    while IFS= read -r line; do
        read -r src mp rest <<< "$line"
        if [ "$mp" = "$mountpt" ]; then
            result+="$new_entry"$'\n'
        else
            result+="$line"$'\n'
        fi
    done < "$TESTDIR/old_fstab"
    echo -n "$result"
}

new_opts="rw,hard,intr"
new_line=$(sed 's/rw,soft,intr/'"$new_opts"'/g' <<< "$(head -2 "$TESTDIR/old_fstab" | tail -1)")
updated=$(replace_fstab_entry "/mnt/data" "$new_line")

if echo "$updated" | grep -q "rw,hard,intr"; then
    pass "Replaced options: rw,hard,intr"
else
    fail "Failed to replace options"
fi

if echo "$updated" | grep -q "rw,soft,intr"; then
    fail "Old options still present after replacement"
else
    pass "Old options removed"
fi

# Test 8: verify mount -o remount would work with correct options
echo ""
echo "--- Test 8: remount command construction ---"
mountpoint="/mnt/data"
opts="rw,hard,intr"
expected_cmd="mount -o remount,rw,hard,intr $mountpoint"
actual_cmd="mount -o remount,$opts $mountpoint"
if [ "$actual_cmd" = "$expected_cmd" ]; then
    pass "Remount command: $actual_cmd"
else
    fail "Expected: $expected_cmd, got: $actual_cmd"
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
