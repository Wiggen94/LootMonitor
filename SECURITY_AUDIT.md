# Security Audit Report - LootMonitor
**Date:** 2025-10-22
**Auditor:** Claude Code Security Analysis
**Project:** LootMonitor - World of Warcraft Addon
**Version:** Latest (commit e76e05e)

---

## Executive Summary

LootMonitor is a World of Warcraft addon written in Lua that displays loot notifications when players receive items or currency. This security audit identified **9 security vulnerabilities** ranging from low to medium severity. No critical vulnerabilities were found.

**Overall Risk Assessment:** LOW-MEDIUM

The addon is client-side only with no network communication, external dependencies, or user authentication. The primary risks involve resource exhaustion, input validation, and saved variable corruption.

---

## Application Overview

- **Type:** World of Warcraft 1.12.1 Client Addon
- **Language:** Lua 5.0
- **Lines of Code:** 1,598
- **Network Communication:** None
- **External Dependencies:** None
- **Data Storage:** WoW SavedVariables (client-side)

---

## Vulnerability Findings

### 1. Quantity Integer Overflow
**Severity:** MEDIUM
**Location:** `LootMonitor.lua:329-361` (ExtractQuantityFromMessage)
**CWE:** CWE-190 (Integer Overflow)

**Description:**
The `ExtractQuantityFromMessage()` function extracts quantity values from loot messages without bounds checking. Line 353 uses `tonumber(quantityStr)` without validating the result is within acceptable ranges.

```lua
local quantity = tonumber(quantityStr)
if quantity and quantity > 0 then
    return quantity
end
```

**Exploit Scenario:**
A malicious addon or modified game client could send chat messages with extremely large quantity values (e.g., "You loot [Item] x999999999"). This could:
- Cause display issues with massive numbers
- Trigger Lua memory issues
- Create performance degradation when counting items in bags

**Recommendation:**
```lua
-- Add bounds checking
local quantity = tonumber(quantityStr)
if quantity and quantity > 0 and quantity <= 999 then  -- Reasonable max
    return quantity
elseif quantity and quantity > 999 then
    return 999  -- Cap at max
end
```

---

### 2. Unlimited Item Name Length
**Severity:** MEDIUM
**Location:** `LootMonitor.lua:538-578` (AddLootItem)
**CWE:** CWE-400 (Uncontrolled Resource Consumption)

**Description:**
Item names extracted from chat messages have no length validation. While `SetWidth()` is called on text frames (line 733), the actual string length is unconstrained.

**Exploit Scenario:**
An extremely long item name (thousands of characters) could:
- Consume excessive memory
- Cause frame rendering performance issues
- Crash the addon or game client with out-of-memory errors

**Recommendation:**
```lua
-- In AddLootItem(), after extracting itemName:
if strlen(itemName) > 100 then
    itemName = strsub(itemName, 1, 97) .. "..."
end
```

---

### 3. Saved Variable Type Confusion
**Severity:** MEDIUM
**Location:** `LootMonitor.lua:227-256` (OnLoad)
**CWE:** CWE-704 (Incorrect Type Conversion)

**Description:**
The `OnLoad()` function loads saved variables without type validation. Line 234 checks if values are `nil` but doesn't verify they're the correct type.

```lua
for key, value in pairs(defaults) do
    if LootMonitorDB[key] == nil then
        LootMonitorDB[key] = value
    end
end
```

**Exploit Scenario:**
A corrupted or manually edited SavedVariables file could contain:
- `LootMonitorDB.scale = "malicious string"` instead of number
- `LootMonitorDB.position = 123` instead of table
- `LootMonitorDB.enabled = function() end` instead of boolean

This would cause runtime errors when these values are used.

**Recommendation:**
```lua
for key, value in pairs(defaults) do
    if LootMonitorDB[key] == nil or type(LootMonitorDB[key]) ~= type(value) then
        if key == "position" then
            LootMonitorDB[key] = {
                point = value.point,
                x = value.x,
                y = value.y
            }
        else
            LootMonitorDB[key] = value
        end
    elseif key == "position" and type(LootMonitorDB[key]) == "table" then
        -- Validate position table structure
        if type(LootMonitorDB[key].point) ~= "string" then
            LootMonitorDB[key].point = value.point
        end
        if type(LootMonitorDB[key].x) ~= "number" then
            LootMonitorDB[key].x = value.x
        end
        if type(LootMonitorDB[key].y) ~= "number" then
            LootMonitorDB[key].y = value.y
        end
    end
end
```

---

### 4. Unconstrained Position Values
**Severity:** LOW
**Location:** `LootMonitor.lua:280-289` (CreateNotificationFrame)
**CWE:** CWE-20 (Improper Input Validation)

**Description:**
Frame position coordinates loaded from saved variables have no range validation. Extreme values could position frames far off-screen.

```lua
local x = LootMonitorDB.position.x
local y = LootMonitorDB.position.y
if x == nil then x = 200 end
if y == nil then y = 100 end
frame:SetPoint(point, UIParent, point, x, y)
```

**Exploit Scenario:**
SavedVariables with `x = 999999, y = -999999` would position the frame completely off-screen, making it impossible to use without manual file editing.

**Recommendation:**
```lua
-- Add range validation
local x = LootMonitorDB.position.x
local y = LootMonitorDB.position.y
if x == nil or x < -2000 or x > 2000 then x = 200 end
if y == nil or y < -2000 or y > 2000 then y = 100 end
```

---

### 5. Resource Exhaustion via OnUpdate Frames
**Severity:** MEDIUM
**Location:** Multiple locations (lines 140-178, 181-208, 847-896, 968-1024, 935-966)
**CWE:** CWE-400 (Uncontrolled Resource Consumption)

**Description:**
Each notification creates up to 5 OnUpdate frames:
1. Quest item check (line 141)
2. Total count update (line 182)
3. Icon search (line 849)
4. Main animation (line 970)
5. Glow animation (line 937)

With `maxNotifications = 5`, this could create 25 concurrent OnUpdate callbacks running every frame.

**Exploit Scenario:**
Rapid looting (or a malicious addon flooding loot messages) could:
- Create dozens of concurrent OnUpdate frames
- Cause significant FPS drops
- Consume excessive CPU resources

**Current Mitigations:**
- Max 5 notifications (line 67)
- Interval-based checks (not every frame)
- Cleanup when notifications expire

**Recommendation:**
Add global OnUpdate frame limit:
```lua
LootMonitor.activeOnUpdateFrames = 0
LootMonitor.maxOnUpdateFrames = 15

-- In each OnUpdate creation:
if LootMonitor.activeOnUpdateFrames >= LootMonitor.maxOnUpdateFrames then
    return  -- Skip this OnUpdate
end
LootMonitor.activeOnUpdateFrames = LootMonitor.activeOnUpdateFrames + 1

-- In cleanup:
LootMonitor.activeOnUpdateFrames = LootMonitor.activeOnUpdateFrames - 1
```

---

### 6. Unsafe getglobal() Usage
**Severity:** LOW
**Location:** `LootMonitor.lua:105, 122`
**CWE:** CWE-470 (Use of Externally-Controlled Input)

**Description:**
The code uses `getglobal()` with string concatenation to access tooltip text:

```lua
local line = getglobal("LootMonitorTooltipTextLeft" .. i)
```

**Risk Assessment:**
Currently LOW because `i` comes from `LootMonitorTooltip:NumLines()` which is controlled by WoW API, not user input. However, this pattern is generally unsafe.

**Recommendation:**
While not immediately exploitable, consider using bracket notation if available in your Lua version, or add validation:
```lua
if type(i) == "number" and i >= 1 and i <= 30 then  -- Reasonable bounds
    local line = getglobal("LootMonitorTooltipTextLeft" .. i)
end
```

---

### 7. Color Code Parsing Without Validation
**Severity:** LOW
**Location:** `LootMonitor.lua:813-826` (UpdateNotificationText)
**CWE:** CWE-1284 (Improper Validation of Specified Quantity)

**Description:**
Hex color codes are parsed from item links without validating the parsing succeeded:

```lua
local r = tonumber(strsub(colorCode, 3, 4), 16) / 255
local g = tonumber(strsub(colorCode, 5, 6), 16) / 255
local b = tonumber(strsub(colorCode, 7, 8), 16) / 255
```

If `tonumber()` fails, it returns `nil`, leading to `nil / 255` which could cause errors.

**Recommendation:**
```lua
local r = tonumber(strsub(colorCode, 3, 4), 16)
local g = tonumber(strsub(colorCode, 5, 6), 16)
local b = tonumber(strsub(colorCode, 7, 8), 16)

if r and g and b then
    notification.cachedColor = {r/255, g/255, b/255}
else
    notification.cachedColor = {1, 1, 1}  -- Fallback
end
```

---

### 8. No Rate Limiting on Loot Messages
**Severity:** LOW
**Location:** `LootMonitor.lua:364-535` (Message processing functions)
**CWE:** CWE-770 (Allocation of Resources Without Limits)

**Description:**
There's no rate limiting on processed loot messages. While there's a max of 5 notifications, rapid message processing could still consume resources.

**Exploit Scenario:**
A malicious addon could spam hundreds of fake loot messages per second, causing:
- Excessive function calls
- String parsing overhead
- Bag scanning operations

**Recommendation:**
```lua
LootMonitor.lastMessageTime = 0
LootMonitor.messageThrottle = 0.05  -- 50ms between messages

function LootMonitor:ProcessLootMessage(message)
    local now = GetTime()
    if now - self.lastMessageTime < self.messageThrottle then
        return  -- Throttle
    end
    self.lastMessageTime = now
    -- ... rest of function
end
```

---

### 9. Potential Pattern Injection in strfind
**Severity:** LOW
**Location:** Multiple locations using `strfind(message, ...)`
**CWE:** CWE-624 (Executable Regular Expression Error)

**Description:**
While Lua patterns are simpler than regex, using user-controlled input in `strfind()` could cause performance issues with malicious patterns. The code uses pre-compiled patterns (good), but some places pass raw message content.

**Risk Assessment:**
Lua's `strfind()` is generally safe from injection, but pathological patterns could cause slow matching.

**Current Mitigations:**
- Most patterns are pre-compiled constants (lines 54-62)
- Pattern matching is used for searching, not substitution

**Recommendation:**
Continue using pre-compiled patterns. No immediate action needed.

---

## Positive Security Findings

### What the addon does WELL:

1. **No Network Communication** - Completely client-side, no data exfiltration risk
2. **No External Dependencies** - Reduces supply chain attack surface
3. **Pre-compiled Patterns** - Lines 54-62 use cached patterns for performance and safety
4. **Notification Limit** - Max 5 active notifications prevents unbounded growth
5. **Interval-based Checks** - OnUpdate scripts use intervals, not every-frame execution
6. **Local Function Caching** - Lines 4-33 cache frequently used functions (good practice)
7. **Escaped Patterns** - Bracket patterns use `%[` and `%]` (properly escaped)
8. **No eval() or loadstring()** - No dynamic code execution
9. **Open Source** - MIT License, transparent code review possible

---

## Recommendations Summary

### High Priority
1. Add bounds checking to quantity extraction (max 999)
2. Validate saved variable types on load
3. Add item name length limits (max 100 characters)

### Medium Priority
4. Implement rate limiting on message processing (50ms throttle)
5. Add global OnUpdate frame limit (max 15)
6. Validate position coordinate ranges (-2000 to 2000)

### Low Priority
7. Add validation to color code parsing
8. Add bounds check to getglobal() index
9. Document security considerations in README

---

## Code Quality Observations

### Strengths:
- Well-organized with clear function names
- Good performance optimizations (caching, local references)
- Proper cleanup of frames and scripts
- Extensive comments explaining functionality

### Areas for Improvement:
- Add input validation layer for all external data
- Implement defensive programming for SavedVariables
- Add error handling for API calls that could fail
- Consider adding debug mode safety checks

---

## Compliance & Standards

**OWASP Top 10 (adapted for client-side code):**
- ✅ A03:2021 - Injection: Low risk (Lua patterns, not SQL/command injection)
- ⚠️ A04:2021 - Insecure Design: Medium risk (missing input validation)
- ⚠️ A05:2021 - Security Misconfiguration: Low risk (SavedVariables validation)
- ✅ A07:2021 - Identification/Auth: N/A (no auth system)
- ✅ A08:2021 - Data Integrity: Good (no external data sources)
- ✅ A09:2021 - Logging Failures: N/A (client-side only)

**CWE Coverage:**
- CWE-20: Improper Input Validation (position values)
- CWE-190: Integer Overflow (quantity parsing)
- CWE-400: Uncontrolled Resource Consumption (OnUpdate frames, name length)
- CWE-470: Externally-Controlled Input (getglobal usage)
- CWE-704: Incorrect Type Conversion (SavedVariables)
- CWE-770: Allocation Without Limits (message processing)

---

## Testing Recommendations

1. **Fuzzing:**
   - Test with extremely long item names (1000+ chars)
   - Test with large quantity values (999999999)
   - Test with malformed item links
   - Test with unusual Unicode characters in names

2. **SavedVariables Corruption:**
   - Manually edit LootMonitorDB with wrong types
   - Test with missing required fields
   - Test with extreme position values

3. **Resource Exhaustion:**
   - Simulate rapid looting (100+ items in 1 second)
   - Monitor FPS and memory usage
   - Test with max notifications active

4. **Integration Testing:**
   - Test with other popular addons
   - Test on different WoW client versions
   - Test with different UI scales and resolutions

---

## Conclusion

LootMonitor is a well-written, client-side WoW addon with **no critical security vulnerabilities**. The identified issues are primarily defensive programming concerns that could cause crashes or performance degradation in edge cases or malicious scenarios.

The addon's biggest security advantages are:
- No network communication
- No external dependencies
- Open source code
- Client-side only operation

**Recommendation:** APPROVE with suggested fixes for medium-priority items.

The addon is safe for general use, but implementing the recommended input validation would make it more robust against edge cases and potential abuse by other addons.

---

## References

- OWASP Top 10 2021: https://owasp.org/Top10/
- CWE/SANS Top 25: https://cwe.mitre.org/top25/
- Lua 5.0 Reference Manual: https://www.lua.org/manual/5.0/
- WoW 1.12.1 API Documentation: https://wowwiki-archive.fandom.com/

---

**Audit Completed:** 2025-10-22
**Next Review Recommended:** Within 6 months or on major version changes
